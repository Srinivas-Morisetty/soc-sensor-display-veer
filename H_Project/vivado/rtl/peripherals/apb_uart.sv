// =============================================================================
// File: apb_uart.sv
// Description: APB UART Peripheral complying with SoC Architecture Document Section 5.1.
// Uses modular uart_tx, uart_rx, and io_generic_fifo from the repository.
// Registers:
//   0x00: TXDATA   [7:0]   W    - Byte to transmit; writing pushes to TX FIFO
//   0x04: RXDATA   [7:0]   R    - Received byte; reading pops from RX FIFO
//   0x08: STATUS   [1:0]   R    - Bit 0: TX FIFO empty, Bit 1: RX FIFO not empty
//   0x0C: BAUDDIV  [15:0]  R/W  - Clock divider setting baud rate
//   0x10: CTRL     [1:0]   R/W  - Bit 0: enable TX, Bit 1: enable RX
// =============================================================================

`timescale 1ns/1ps

module apb_uart #(
    parameter int APB_ADDR_WIDTH = 12,
    parameter int APB_DATA_WIDTH = 32,
    parameter int FIFO_DEPTH      = 16
)(
    input  logic                      pclk,
    input  logic                      prstn,

    // APB Slave Interface
    input  logic [APB_ADDR_WIDTH-1:0] paddr,
    input  logic                      psel,
    input  logic                      penable,
    input  logic                      pwrite,
    input  logic [APB_DATA_WIDTH-1:0] pwdata,
    output logic [APB_DATA_WIDTH-1:0] prdata,
    output logic                      pready,
    output logic                      pslverr,

    // Serial Lines
    input  logic                      uart_rx,
    output logic                      uart_tx,

    // Interrupt output (RX not empty or TX empty)
    output logic                      irq_uart
);

    // Register Offsets
    localparam logic [7:0] OFF_TXDATA  = 8'h00;
    localparam logic [7:0] OFF_RXDATA  = 8'h04;
    localparam logic [7:0] OFF_STATUS  = 8'h08;
    localparam logic [7:0] OFF_BAUDDIV = 8'h0C;
    localparam logic [7:0] OFF_CTRL    = 8'h10;

    // Control and Config Registers
    logic [15:0] reg_bauddiv;
    logic [1:0]  reg_ctrl; // bit 0: tx_en, bit 1: rx_en

    // FIFO signals
    logic        tx_fifo_valid_in;
    logic [7:0]  tx_fifo_data_in;
    logic        tx_fifo_ready_out;
    logic [7:0]  tx_fifo_data_out;
    logic        tx_fifo_valid_out;
    logic        tx_fifo_ready_in;
    logic [$clog2(FIFO_DEPTH):0] tx_elements;

    logic        rx_fifo_valid_in;
    logic [7:0]  rx_fifo_data_in;
    logic        rx_fifo_ready_out;
    logic [7:0]  rx_fifo_data_out;
    logic        rx_fifo_valid_out;
    logic        rx_fifo_ready_in;
    logic [$clog2(FIFO_DEPTH):0] rx_elements;

    // Transmit & Receive signals
    logic        uart_tx_busy;
    logic        uart_rx_busy;
    logic        uart_rx_err;
    logic [7:0]  rx_byte_out;
    logic        rx_byte_valid;

    // Status bits
    logic tx_empty;
    logic rx_not_empty;
    assign tx_empty     = (tx_elements == '0) && !uart_tx_busy;
    assign rx_not_empty = (rx_elements != '0) || rx_fifo_valid_out;

    assign irq_uart     = rx_not_empty;

    // Single-cycle APB slave response
    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // APB Write & Read Decode
    logic apb_write_pulse;
    logic apb_read_pulse;
    assign apb_write_pulse = psel && penable && pwrite;
    assign apb_read_pulse  = psel && !penable && !pwrite; // pop at start of read transfer

    // Pop RX FIFO on reading RXDATA
    assign rx_fifo_ready_in = (psel && penable && !pwrite && (paddr[7:0] == OFF_RXDATA));

    // Push TX FIFO on writing TXDATA
    always_comb begin
        tx_fifo_valid_in = 1'b0;
        tx_fifo_data_in  = pwdata[7:0];
        if (apb_write_pulse && (paddr[7:0] == OFF_TXDATA) && reg_ctrl[0]) begin
            tx_fifo_valid_in = 1'b1;
        end
    end

    // APB Registers Write Process
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_bauddiv <= 16'd10; // default safe clock divider
            reg_ctrl    <= 2'b00;  // disabled by default
        end else if (apb_write_pulse) begin
            case (paddr[7:0])
                OFF_BAUDDIV: reg_bauddiv <= pwdata[15:0];
                OFF_CTRL:    reg_ctrl    <= pwdata[1:0];
                default: ;
            endcase
        end
    end

    // APB Read Data Multiplexer
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_RXDATA:  prdata = {24'd0, rx_fifo_data_out};
            OFF_STATUS:  prdata = {30'd0, rx_not_empty, tx_empty};
            OFF_BAUDDIV: prdata = {16'd0, reg_bauddiv};
            OFF_CTRL:    prdata = {30'd0, reg_ctrl};
            default:     prdata = '0;
        endcase
    end

    // TX FIFO Instance
    io_generic_fifo #(
        .DATA_WIDTH(8),
        .BUFFER_DEPTH(FIFO_DEPTH)
    ) u_tx_fifo (
        .clk_i      (pclk),
        .rstn_i     (prstn),
        .clr_i      (!reg_ctrl[0]),
        .elements_o (tx_elements),
        .data_o     (tx_fifo_data_out),
        .valid_o    (tx_fifo_valid_out),
        .ready_i    (tx_fifo_ready_in),
        .valid_i    (tx_fifo_valid_in),
        .data_i     (tx_fifo_data_in),
        .ready_o    (tx_fifo_ready_out)
    );

    // UART TX Transmitter
    uart_tx u_uart_tx (
        .clk_i           (pclk),
        .rstn_i          (prstn),
        .tx_o            (uart_tx),
        .busy_o          (uart_tx_busy),
        .cfg_en_i        (reg_ctrl[0]),
        .cfg_div_i       (reg_bauddiv),
        .cfg_parity_en_i (1'b0),
        .cfg_bits_i      (2'b11), // 8 data bits
        .cfg_stop_bits_i (1'b0), // 1 stop bit
        .tx_data_i       (tx_fifo_data_out),
        .tx_valid_i      (tx_fifo_valid_out),
        .tx_ready_o      (tx_fifo_ready_in)
    );

    // UART RX Receiver
    uart_rx u_uart_rx (
        .clk_i           (pclk),
        .rstn_i          (prstn),
        .rx_i            (uart_rx),
        .cfg_div_i       (reg_bauddiv),
        .cfg_en_i        (reg_ctrl[1]),
        .cfg_parity_en_i (1'b0),
        .cfg_bits_i      (2'b11), // 8 data bits
        .busy_o          (uart_rx_busy),
        .err_o           (uart_rx_err),
        .err_clr_i       (1'b1),
        .rx_data_o       (rx_byte_out),
        .rx_valid_o      (rx_byte_valid),
        .rx_ready_i      (rx_fifo_ready_out)
    );

    // RX FIFO Instance
    io_generic_fifo #(
        .DATA_WIDTH(8),
        .BUFFER_DEPTH(FIFO_DEPTH)
    ) u_rx_fifo (
        .clk_i      (pclk),
        .rstn_i     (prstn),
        .clr_i      (!reg_ctrl[1]),
        .elements_o (rx_elements),
        .data_o     (rx_fifo_data_out),
        .valid_o    (rx_fifo_valid_out),
        .ready_i    (rx_fifo_ready_in),
        .valid_i    (rx_byte_valid),
        .data_i     (rx_byte_out),
        .ready_o    (rx_fifo_ready_out)
    );

endmodule : apb_uart
