// =============================================================================
// File: soc_top.sv
// Description: Top-Level SoC Module for Sensor-Driven Multiplexed 7-Segment Display.
// Integrates:
//   - AHB-Lite System Interconnect
//   - 64 KB Instruction Memory (ICCM @ 0x0000_0000)
//   - 64 KB Data Memory (DCCM @ 0x1000_0000)
//   - AHB-to-APB Protocol Bridge
//   - APB Interconnect (1-to-6 Decoder)
//   - 6 APB Peripherals:
//       * 0x8000_0000: UART
//       * 0x8000_1000: Timer
//       * 0x8000_2000: 32-bit GPIO
//       * 0x8000_3000: 4-Digit Seven-Segment Controller (Custom IP)
//       * 0x8000_4000: PWM Generator (Custom IP)
//       * 0x8000_5000: 12-bit ADC Interface (Custom IP)
// =============================================================================

`timescale 1ns/1ps

module soc_top (
    input  logic        clk,
    input  logic        rst_n,

    // External AHB-Lite Master Port (Core or Testbench Bus Master)
    input  logic [31:0] m_haddr,
    input  logic [1:0]  m_htrans,
    input  logic        m_hwrite,
    input  logic [2:0]  m_hsize,
    input  logic [31:0] m_hwdata,
    output logic [31:0] m_hrdata,
    output logic        m_hready,
    output logic        m_hresp,

    // UART External Lines
    input  logic        uart_rx,
    output logic        uart_tx,

    // GPIO External Lines
    input  logic [31:0] gpio_i,
    output logic [31:0] gpio_o,
    output logic [31:0] gpio_oe,

    // Seven-Segment Display External Lines
    output logic [7:0]  seg_out,
    output logic [3:0]  digit_sel,

    // PWM Output (Brightness / Indicator)
    output logic        pwm_out,

    // Sensor / ADC Input
    input  logic [11:0] sensor_in,

    // System Interrupt Lines (to PIC / external)
    output logic        irq_timer,
    output logic        irq_adc,
    output logic        irq_uart
);

    // =========================================================================
    // AHB-Lite Interconnect & Address Decoder
    // =========================================================================
    // Memory map:
    // 0x0000_0000 - 0x0000_FFFF: ICCM (64 KB)
    // 0x1000_0000 - 0x1000_FFFF: DCCM (64 KB)
    // 0x8000_0000 - 0x8000_FFFF: APB Peripherals (via Bridge)

    logic hsel_iccm;
    logic hsel_dccm;
    logic hsel_bridge;

    always_comb begin
        hsel_iccm   = 1'b0;
        hsel_dccm   = 1'b0;
        hsel_bridge = 1'b0;

        if (m_htrans == 2'b10 || m_htrans == 2'b11) begin
            if (m_haddr[31:16] == 16'h0000) begin
                hsel_iccm = 1'b1;
            end else if (m_haddr[31:16] == 16'h1000) begin
                hsel_dccm = 1'b1;
            end else if (m_haddr[31:16] == 16'h8000) begin
                hsel_bridge = 1'b1;
            end
        end
    end

    // Slave AHB Responses
    logic [31:0] hrdata_iccm, hrdata_dccm, hrdata_bridge;
    logic        hreadyout_iccm, hreadyout_dccm, hreadyout_bridge;
    logic        hresp_iccm, hresp_dccm, hresp_bridge;

    // Registered slave select for data phase multiplexing
    logic [1:0] slave_sel_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_sel_q <= 2'b00;
        end else if (m_hready) begin
            if (hsel_iccm)        slave_sel_q <= 2'b00;
            else if (hsel_dccm)   slave_sel_q <= 2'b01;
            else if (hsel_bridge) slave_sel_q <= 2'b10;
            else                  slave_sel_q <= 2'b11;
        end
    end

    // Multiplex AHB Read Data & Ready
    always_comb begin
        case (slave_sel_q)
            2'b00: begin
                m_hrdata = hrdata_iccm;
                m_hready = hreadyout_iccm;
                m_hresp  = hresp_iccm;
            end
            2'b01: begin
                m_hrdata = hrdata_dccm;
                m_hready = hreadyout_dccm;
                m_hresp  = hresp_dccm;
            end
            2'b10: begin
                m_hrdata = hrdata_bridge;
                m_hready = hreadyout_bridge;
                m_hresp  = hresp_bridge;
            end
            default: begin
                m_hrdata = 32'hDEAD_BEEF;
                m_hready = 1'b1;
                m_hresp  = 1'b1; // ERROR for unmapped address
            end
        endcase
    end

    // =========================================================================
    // Instruction Memory (ICCM - 64 KB)
    // =========================================================================
    iccm #(
        .ADDR_WIDTH(16),
        .DATA_WIDTH(32)
    ) u_iccm (
        .hclk      (clk),
        .hresetn   (rst_n),
        .haddr     (m_haddr),
        .htrans    (m_htrans),
        .hwrite    (m_hwrite),
        .hsize     (m_hsize),
        .hwdata    (m_hwdata),
        .hsel      (hsel_iccm),
        .hready    (m_hready),
        .hrdata    (hrdata_iccm),
        .hreadyout (hreadyout_iccm),
        .hresp     (hresp_iccm)
    );

    // =========================================================================
    // Data Memory (DCCM - 64 KB)
    // =========================================================================
    dccm #(
        .ADDR_WIDTH(16),
        .DATA_WIDTH(32)
    ) u_dccm (
        .hclk      (clk),
        .hresetn   (rst_n),
        .haddr     (m_haddr),
        .htrans    (m_htrans),
        .hwrite    (m_hwrite),
        .hsize     (m_hsize),
        .hwdata    (m_hwdata),
        .hsel      (hsel_dccm),
        .hready    (m_hready),
        .hrdata    (hrdata_dccm),
        .hreadyout (hreadyout_dccm),
        .hresp     (hresp_dccm)
    );

    // =========================================================================
    // AHB-to-APB Bridge
    // =========================================================================
    logic [31:0] paddr_bridge;
    logic        psel_bridge;
    logic        penable_bridge;
    logic        pwrite_bridge;
    logic [31:0] pwdata_bridge;
    logic [31:0] prdata_bridge;
    logic        pready_bridge;
    logic        pslverr_bridge;

    ahb_to_apb_bridge u_bridge (
        .hclk      (clk),
        .hresetn   (rst_n),
        .haddr     (m_haddr),
        .htrans    (m_htrans),
        .hwrite    (m_hwrite),
        .hsize     (m_hsize),
        .hwdata    (m_hwdata),
        .hsel      (hsel_bridge),
        .hready    (m_hready),
        .hrdata    (hrdata_bridge),
        .hreadyout (hreadyout_bridge),
        .hresp     (hresp_bridge),

        .paddr     (paddr_bridge),
        .psel      (psel_bridge),
        .penable   (penable_bridge),
        .pwrite    (pwrite_bridge),
        .pwdata    (pwdata_bridge),
        .prdata    (prdata_bridge),
        .pready    (pready_bridge),
        .pslverr   (pslverr_bridge)
    );

    // =========================================================================
    // APB Interconnect (1-to-6 Peripheral Address Decoder)
    // =========================================================================
    localparam int NUM_PERIPHS = 6;
    logic [31:0] periph_paddr;
    logic        periph_penable;
    logic        periph_pwrite;
    logic [31:0] periph_pwdata;
    logic [NUM_PERIPHS-1:0] periph_psel;

    logic [31:0] periph_prdata  [NUM_PERIPHS];
    logic [NUM_PERIPHS-1:0] periph_pready;
    logic [NUM_PERIPHS-1:0] periph_pslverr;

    apb_interconnect #(
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32),
        .NUM_SLAVES(NUM_PERIPHS)
    ) u_apb_interconnect (
        .pclk      (clk),
        .presetn   (rst_n),

        .s_paddr   (paddr_bridge),
        .s_psel    (psel_bridge),
        .s_penable (penable_bridge),
        .s_pwrite  (pwrite_bridge),
        .s_pwdata  (pwdata_bridge),
        .s_prdata  (prdata_bridge),
        .s_pready  (pready_bridge),
        .s_pslverr (pslverr_bridge),

        .m_paddr   (periph_paddr),
        .m_penable (periph_penable),
        .m_pwrite  (periph_pwrite),
        .m_pwdata  (periph_pwdata),
        .m_psel    (periph_psel),
        .m_prdata  (periph_prdata),
        .m_pready  (periph_pready),
        .m_pslverr (periph_pslverr)
    );

    // =========================================================================
    // Peripheral 0: UART (0x8000_0000)
    // =========================================================================
    apb_uart u_uart (
        .pclk     (clk),
        .prstn    (rst_n),
        .paddr    (periph_paddr[11:0]),
        .psel     (periph_psel[0]),
        .penable  (periph_penable),
        .pwrite   (periph_pwrite),
        .pwdata   (periph_pwdata),
        .prdata   (periph_prdata[0]),
        .pready   (periph_pready[0]),
        .pslverr  (periph_pslverr[0]),
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .irq_uart (irq_uart)
    );

    // =========================================================================
    // Peripheral 1: Timer (0x8000_1000)
    // =========================================================================
    apb_timer u_timer (
        .pclk      (clk),
        .prstn     (rst_n),
        .paddr     (periph_paddr[11:0]),
        .psel      (periph_psel[1]),
        .penable   (periph_penable),
        .pwrite    (periph_pwrite),
        .pwdata    (periph_pwdata),
        .prdata    (periph_prdata[1]),
        .pready    (periph_pready[1]),
        .pslverr   (periph_pslverr[1]),
        .irq_timer (irq_timer)
    );

    // =========================================================================
    // Peripheral 2: GPIO (0x8000_2000)
    // =========================================================================
    apb_gpio u_gpio (
        .pclk    (clk),
        .prstn   (rst_n),
        .paddr   (periph_paddr[11:0]),
        .psel    (periph_psel[2]),
        .penable (periph_penable),
        .pwrite  (periph_pwrite),
        .pwdata  (periph_pwdata),
        .prdata  (periph_prdata[2]),
        .pready  (periph_pready[2]),
        .pslverr (periph_pslverr[2]),
        .gpio_i  (gpio_i),
        .gpio_o  (gpio_o),
        .gpio_oe (gpio_oe)
    );

    // =========================================================================
    // Peripheral 3: Seven-Segment Display Controller (0x8000_3000)
    // =========================================================================
    apb_seven_seg u_seven_seg (
        .pclk      (clk),
        .prstn     (rst_n),
        .paddr     (periph_paddr[11:0]),
        .psel      (periph_psel[3]),
        .penable   (periph_penable),
        .pwrite    (periph_pwrite),
        .pwdata    (periph_pwdata),
        .prdata    (periph_prdata[3]),
        .pready    (periph_pready[3]),
        .pslverr   (periph_pslverr[3]),
        .seg_out   (seg_out),
        .digit_sel (digit_sel)
    );

    // =========================================================================
    // Peripheral 4: PWM Generator (0x8000_4000)
    // =========================================================================
    apb_pwm u_pwm (
        .pclk    (clk),
        .prstn   (rst_n),
        .paddr   (periph_paddr[11:0]),
        .psel    (periph_psel[4]),
        .penable (periph_penable),
        .pwrite  (periph_pwrite),
        .pwdata  (periph_pwdata),
        .prdata  (periph_prdata[4]),
        .pready  (periph_pready[4]),
        .pslverr (periph_pslverr[4]),
        .pwm_out (pwm_out)
    );

    // =========================================================================
    // Peripheral 5: ADC Interface (0x8000_5000)
    // =========================================================================
    logic conv_active;

    apb_adc u_adc (
        .pclk        (clk),
        .prstn       (rst_n),
        .paddr       (periph_paddr[11:0]),
        .psel        (periph_psel[5]),
        .penable     (periph_penable),
        .pwrite      (periph_pwrite),
        .pwdata      (periph_pwdata),
        .prdata      (periph_prdata[5]),
        .pready      (periph_pready[5]),
        .pslverr     (periph_pslverr[5]),
        .sensor_in   (sensor_in),
        .conv_active (conv_active),
        .irq_adc     (irq_adc)
    );

endmodule : soc_top
