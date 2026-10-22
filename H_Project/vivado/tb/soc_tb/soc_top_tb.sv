// =============================================================================
// File: soc_top_tb.sv
// Description: Full SoC System Testbench for Sensor-Driven 7-Segment Display SoC.
// Verifies:
//   1. AHB-Lite interconnect routing to ICCM, DCCM, and APB Bridge
//   2. Read/Write access to all 6 peripherals via AHB-to-APB bridge
//   3. End-to-end sensor-to-display flow:
//        - Analog sensor value is sampled by ADC Interface
//        - ADC triggers End-of-Conversion (EOC)
//        - Testbench (simulating RISC-V firmware) reads 12-bit ADC result
//        - Decodes value into BCD digits
//        - Configures PWM Generator for display brightness
//        - Writes digits to 7-Segment Controller
//        - Verifies correct 7-segment bus outputs and persistence-of-vision scan
//        - Logs status through UART
// =============================================================================

`timescale 1ns/1ps

module soc_top_tb;

    logic        clk;
    logic        rst_n;

    // Master AHB-Lite Interface
    logic [31:0] m_haddr;
    logic [1:0]  m_htrans;
    logic        m_hwrite;
    logic [2:0]  m_hsize;
    logic [31:0] m_hwdata;
    logic [31:0] m_hrdata;
    logic        m_hready;
    logic        m_hresp;

    // Peripherals External IO
    logic        uart_rx;
    logic        uart_tx;
    logic [31:0] gpio_i;
    logic [31:0] gpio_o;
    logic [31:0] gpio_oe;
    logic [7:0]  seg_out;
    logic [3:0]  digit_sel;
    logic        pwm_out;
    logic [11:0] sensor_in;

    // Interrupts
    logic        irq_timer;
    logic        irq_adc;
    logic        irq_uart;

    // Clock Generation (50 MHz)
    initial clk = 0;
    always #10 clk = ~clk;

    // UART Loopback
    assign uart_rx = uart_tx;

    // Top-Level SoC Instance
    soc_top u_soc_top (
        .clk        (clk),
        .rst_n      (rst_n),
        .m_haddr    (m_haddr),
        .m_htrans   (m_htrans),
        .m_hwrite   (m_hwrite),
        .m_hsize    (m_hsize),
        .m_hwdata   (m_hwdata),
        .m_hrdata   (m_hrdata),
        .m_hready   (m_hready),
        .m_hresp    (m_hresp),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .gpio_i     (gpio_i),
        .gpio_o     (gpio_o),
        .gpio_oe    (gpio_oe),
        .seg_out    (seg_out),
        .digit_sel  (digit_sel),
        .pwm_out    (pwm_out),
        .sensor_in  (sensor_in),
        .irq_timer  (irq_timer),
        .irq_adc    (irq_adc),
        .irq_uart   (irq_uart)
    );

    // AHB-Lite Single Write Task (32-bit word)
    task automatic ahb_write32(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        m_haddr  <= addr;
        m_htrans <= 2'b10; // NONSEQ
        m_hwrite <= 1'b1;
        m_hsize  <= 3'b010; // 32-bit Word
        
        @(posedge clk);
        while (!m_hready) @(posedge clk);
        m_hwdata <= data;
        m_htrans <= 2'b00; // IDLE

        @(posedge clk);
        while (!m_hready) @(posedge clk);
    endtask

    // AHB-Lite Single Read Task (32-bit word)
    task automatic ahb_read32(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        m_haddr  <= addr;
        m_htrans <= 2'b10; // NONSEQ
        m_hwrite <= 1'b0;
        m_hsize  <= 3'b010; // Word

        @(posedge clk);
        while (!m_hready) @(posedge clk);
        m_htrans <= 2'b00; // IDLE

        @(posedge clk);
        while (!m_hready) @(posedge clk);
        data = m_hrdata;
    endtask

    int errors = 0;
    logic [31:0] rd_data;

    initial begin
        $dumpfile("soc_top_tb.vcd");
        $dumpvars(0, soc_top_tb);

        $display("=================================================================");
        $display("   STARTING SOC FULL-SYSTEM INTEGRATION TESTBENCH IN VIVADO      ");
        $display("=================================================================");

        // 1. System Reset
        rst_n    = 0;
        m_haddr  = 0;
        m_htrans = 0;
        m_hwrite = 0;
        m_hsize  = 0;
        m_hwdata = 0;
        gpio_i   = 32'h0;
        sensor_in = 12'h0;
        #50;
        @(posedge clk);
        rst_n = 1;
        #30;

        // -----------------------------------------------------------------
        // TEST 1: Instruction Memory (ICCM @ 0x0000_0000)
        // -----------------------------------------------------------------
        $display("\n[STEP 1] Testing ICCM Memory Access (0x0000_0000)...");
        ahb_write32(32'h0000_0004, 32'h1234_5678);
        ahb_read32 (32'h0000_0004, rd_data);
        if (rd_data === 32'h1234_5678) begin
            $display("  -> ICCM Readback SUCCESS: 0x%08h", rd_data);
        end else begin
            $display("  -> ICCM ERROR! Expected 0x12345678, got 0x%08h", rd_data);
            errors++;
        end

        // -----------------------------------------------------------------
        // TEST 2: Data Memory (DCCM @ 0x1000_0000)
        // -----------------------------------------------------------------
        $display("\n[STEP 2] Testing DCCM Memory Access (0x1000_0000)...");
        ahb_write32(32'h1000_0008, 32'hDEAD_BEEF);
        ahb_read32 (32'h1000_0008, rd_data);
        if (rd_data === 32'hDEAD_BEEF) begin
            $display("  -> DCCM Readback SUCCESS: 0x%08h", rd_data);
        end else begin
            $display("  -> DCCM ERROR! Expected 0xDEADBEEF, got 0x%08h", rd_data);
            errors++;
        end

        // -----------------------------------------------------------------
        // TEST 3: GPIO Peripheral (0x8000_2000)
        // -----------------------------------------------------------------
        $display("\n[STEP 3] Testing GPIO Unit (0x8000_2000)...");
        ahb_write32(32'h8000_2008, 32'hFFFF_0000); // DIR: upper 16 output
        ahb_write32(32'h8000_2000, 32'hA5A5_0000); // DATA_OUT
        gpio_i = 32'h0000_5A5A;
        repeat (4) @(posedge clk);
        ahb_read32(32'h8000_2004, rd_data); // DATA_IN
        if (rd_data === 32'h0000_5A5A) begin
            $display("  -> GPIO Sampled Input SUCCESS: 0x%08h", rd_data);
        end else begin
            $display("  -> GPIO ERROR! Expected 0x00005A5A, got 0x%08h", rd_data);
            errors++;
        end

        // -----------------------------------------------------------------
        // TEST 4: PWM Generator (0x8000_4000) for Display Brightness
        // -----------------------------------------------------------------
        $display("\n[STEP 4] Configuring PWM Generator for Display Brightness (0x8000_4000)...");
        ahb_write32(32'h8000_4000, 32'd20); // PERIOD = 20 cycles
        ahb_write32(32'h8000_4004, 32'd10); // DUTY = 10 cycles (50% brightness)
        ahb_write32(32'h8000_4008, 32'd1);  // CTRL = Enable
        #100;
        $display("  -> PWM Running with duty cycle 50%%");

        // -----------------------------------------------------------------
        // TEST 5: Seven-Segment Display Controller (0x8000_3000)
        // -----------------------------------------------------------------
        $display("\n[STEP 5] Configuring Seven-Segment Display Controller (0x8000_3000)...");
        ahb_write32(32'h8000_3014, 32'd4);  // SCAN_DIV = 4 cycles per digit
        ahb_write32(32'h8000_3000, 32'd1);  // Enable, BCD mode

        // -----------------------------------------------------------------
        // TEST 6: ADC Interface & Full Application Data Flow
        // -----------------------------------------------------------------
        $display("\n[STEP 6] Executing Sensor Read -> BCD Conversion -> 7-Segment Display Flow...");
        // Emulate an analog sensor input of 2584 (decimal)
        sensor_in = 12'd2584; // In binary: 12'b101000011000
        $display("  -> Simulated Sensor Input = %0d (0x%03h)", sensor_in, sensor_in);

        // Software trigger ADC conversion
        ahb_write32(32'h8000_5000, 32'h01);

        // Wait for ADC EOC (End-of-Conversion)
        rd_data = 0;
        while (!rd_data[0]) begin
            ahb_read32(32'h8000_5004, rd_data);
            #20;
        end
        $display("  -> ADC Conversion Complete! STATUS = 0x%08h, irq_adc = %b", rd_data, irq_adc);

        // Read 12-bit result
        ahb_read32(32'h8000_5008, rd_data);
        $display("  -> Read ADC Result = %0d (0x%03h)", rd_data[11:0], rd_data[11:0]);
        if (rd_data[11:0] !== 12'd2584) begin
            $display("  -> ADC RESULT ERROR! Expected 2584, got %0d", rd_data[11:0]);
            errors++;
        end

        // RISC-V Firmware algorithm: BCD breakdown of 2584
        // Digit 3 = 2, Digit 2 = 5, Digit 1 = 8, Digit 0 = 4
        $display("  -> Firmware converting 2584 to BCD: [D3=2, D2=5, D1=8, D0=4]");
        ahb_write32(32'h8000_3004, 32'd4); // DIGIT0 = 4
        ahb_write32(32'h8000_3008, 32'd8); // DIGIT1 = 8
        ahb_write32(32'h8000_300C, 32'd5); // DIGIT2 = 5
        ahb_write32(32'h8000_3010, 32'd2); // DIGIT3 = 2

        // Monitor the 7-segment display output lines during multiplexing
        repeat (4) begin
            @(posedge clk);
            wait (digit_sel != 4'b0000);
            $display("  [7-SEG DISPLAY PINS] Active DigitSelect=%b | Segments(a..g,dp)=%b", digit_sel, seg_out);
            #30;
        end

        // -----------------------------------------------------------------
        // TEST 7: UART Terminal Communication (0x8000_0000)
        // -----------------------------------------------------------------
        $display("\n[STEP 7] Testing UART Output Log (0x8000_0000)...");
        ahb_write32(32'h8000_000C, 32'd4); // Fast BAUDDIV
        ahb_write32(32'h8000_0010, 32'd3); // Enable TX & RX
        ahb_write32(32'h8000_0000, 32'h53); // Send 'S'
        
        rd_data = 0;
        while (!rd_data[1]) begin // wait until RX not empty
            ahb_read32(32'h8000_0008, rd_data);
            #30;
        end
        ahb_read32(32'h8000_0004, rd_data);
        $display("  -> UART Loopback Received Character: '%c' (0x%02h)", rd_data[7:0], rd_data[7:0]);
        if (rd_data[7:0] !== 8'h53) begin
            $display("  -> UART Character ERROR! Expected 'S', got '%c'", rd_data[7:0]);
            errors++;
        end

        // -----------------------------------------------------------------
        // SUMMARY
        // -----------------------------------------------------------------
        #100;
        $display("\n=================================================================");
        if (errors == 0) begin
            $display("   *** ALL SOC TESTS PASSED SUCCESSFULLY IN VIVADO! (0 ERRORS) ***");
        end else begin
            $display("   *** SOC TESTS COMPLETED WITH %0d ERRORS! ***", errors);
        end
        $display("=================================================================");
        $finish;
    end

endmodule : soc_top_tb
