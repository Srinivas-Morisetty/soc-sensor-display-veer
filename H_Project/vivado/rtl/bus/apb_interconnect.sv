// =============================================================================
// File: apb_interconnect.sv
// Description: 1-to-6 APB Interconnect / Address Decoder.
// Routes transactions from AHB-to-APB bridge to the 6 peripherals:
//   - 0x8000_0000: UART
//   - 0x8000_1000: Timer
//   - 0x8000_2000: GPIO
//   - 0x8000_3000: Seven-Segment Display Controller
//   - 0x8000_4000: PWM Generator
//   - 0x8000_5000: ADC Interface
// =============================================================================

`timescale 1ns/1ps

module apb_interconnect #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int NUM_SLAVES = 6
)(
    // Clock and Reset
    input  logic                  pclk,
    input  logic                  presetn,

    // Master (from AHB-to-APB bridge)
    input  logic [ADDR_WIDTH-1:0] s_paddr,
    input  logic                  s_psel,
    input  logic                  s_penable,
    input  logic                  s_pwrite,
    input  logic [DATA_WIDTH-1:0] s_pwdata,
    output logic [DATA_WIDTH-1:0] s_prdata,
    output logic                  s_pready,
    output logic                  s_pslverr,

    // Slaves (to peripherals)
    // Common bus signals
    output logic [ADDR_WIDTH-1:0] m_paddr,
    output logic                  m_penable,
    output logic                  m_pwrite,
    output logic [DATA_WIDTH-1:0] m_pwdata,

    // Individual select signals
    output logic [NUM_SLAVES-1:0] m_psel,

    // Individual slave responses
    input  logic [DATA_WIDTH-1:0] m_prdata  [NUM_SLAVES],
    input  logic [NUM_SLAVES-1:0] m_pready,
    input  logic [NUM_SLAVES-1:0] m_pslverr
);

    // Pass-through broadcast signals
    assign m_paddr   = s_paddr;
    assign m_penable = s_penable;
    assign m_pwrite  = s_pwrite;
    assign m_pwdata  = s_pwdata;

    // Address decode logic (4KB aperture per peripheral)
    // Base is 0x8000_0000; paddr[15:12] gives index 0..5
    logic [2:0] slave_sel;
    logic       valid_range;

    always_comb begin
        m_psel      = '0;
        valid_range = 1'b0;
        slave_sel   = '0;

        if (s_psel && (s_paddr[31:16] == 16'h8000)) begin
            case (s_paddr[15:12])
                4'h0: begin m_psel[0] = 1'b1; slave_sel = 3'd0; valid_range = 1'b1; end // UART
                4'h1: begin m_psel[1] = 1'b1; slave_sel = 3'd1; valid_range = 1'b1; end // Timer
                4'h2: begin m_psel[2] = 1'b1; slave_sel = 3'd2; valid_range = 1'b1; end // GPIO
                4'h3: begin m_psel[3] = 1'b1; slave_sel = 3'd3; valid_range = 1'b1; end // 7-Segment
                4'h4: begin m_psel[4] = 1'b1; slave_sel = 3'd4; valid_range = 1'b1; end // PWM
                4'h5: begin m_psel[5] = 1'b1; slave_sel = 3'd5; valid_range = 1'b1; end // ADC
                default: begin
                    valid_range = 1'b0;
                end
            endcase
        end
    end

    // Response multiplexing
    always_comb begin
        if (!valid_range && s_psel) begin
            // Unmapped peripheral access
            s_prdata  = 32'hDEAD_BEEF;
            s_pready  = 1'b1;
            s_pslverr = 1'b1; // Error response for reserved address
        end else if (valid_range) begin
            s_prdata  = m_prdata[slave_sel];
            s_pready  = m_pready[slave_sel];
            s_pslverr = m_pslverr[slave_sel];
        end else begin
            s_prdata  = '0;
            s_pready  = 1'b1;
            s_pslverr = 1'b0;
        end
    end

endmodule : apb_interconnect
