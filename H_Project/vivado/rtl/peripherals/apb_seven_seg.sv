// =============================================================================
// File: apb_seven_seg.sv
// Description: APB 4-Digit Multiplexed Seven-Segment Display Controller
// Conforms to SoC Architecture Document Section 5.4.
//
// Registers:
//   0x00: CTRL     [2:0]  R/W - Bit 0: enable, Bit 1: blank, Bit 2: digit format (0=BCD, 1=raw)
//   0x04: DIGIT0   [7:0]  R/W - Digit 0 (rightmost) value + dp in bit 7
//   0x08: DIGIT1   [7:0]  R/W - Digit 1 value + dp in bit 7
//   0x0C: DIGIT2   [7:0]  R/W - Digit 2 value + dp in bit 7
//   0x10: DIGIT3   [7:0]  R/W - Digit 3 (leftmost) value + dp in bit 7
//   0x14: SCAN_DIV [15:0] R/W - Clock divider setting scan refresh rate
//   0x18: STATUS   [1:0]  R   - Currently active digit index (0-3)
// =============================================================================

`timescale 1ns/1ps

module apb_seven_seg #(
    parameter int APB_ADDR_WIDTH = 12,
    parameter int APB_DATA_WIDTH = 32
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

    // 7-Segment Display Pins
    output logic [7:0]                seg_out,   // [6:0] = a..g, [7] = dp
    output logic [3:0]                digit_sel  // One-hot active digit select
);

    // Register Offsets
    localparam logic [7:0] OFF_CTRL     = 8'h00;
    localparam logic [7:0] OFF_DIGIT0   = 8'h04;
    localparam logic [7:0] OFF_DIGIT1   = 8'h08;
    localparam logic [7:0] OFF_DIGIT2   = 8'h0C;
    localparam logic [7:0] OFF_DIGIT3   = 8'h10;
    localparam logic [7:0] OFF_SCAN_DIV = 8'h14;
    localparam logic [7:0] OFF_STATUS   = 8'h18;

    // Registers
    logic [2:0]  reg_ctrl;     // [0]=en, [1]=blank, [2]=format
    logic [7:0]  reg_digit [4];
    logic [15:0] reg_scan_div;

    // Internal Scan Multiplexer Signals
    logic [15:0] scan_counter;
    logic [1:0]  current_digit;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    logic apb_write_pulse;
    assign apb_write_pulse = psel && penable && pwrite;

    // Register Write
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_ctrl     <= 3'b000;
            reg_digit[0] <= 8'h00;
            reg_digit[1] <= 8'h00;
            reg_digit[2] <= 8'h00;
            reg_digit[3] <= 8'h00;
            reg_scan_div <= 16'd50; // Fast scan for simulation by default
        end else if (apb_write_pulse) begin
            case (paddr[7:0])
                OFF_CTRL:     reg_ctrl     <= pwdata[2:0];
                OFF_DIGIT0:   reg_digit[0] <= pwdata[7:0];
                OFF_DIGIT1:   reg_digit[1] <= pwdata[7:0];
                OFF_DIGIT2:   reg_digit[2] <= pwdata[7:0];
                OFF_DIGIT3:   reg_digit[3] <= pwdata[7:0];
                OFF_SCAN_DIV: reg_scan_div <= pwdata[15:0];
                default: ;
            endcase
        end
    end

    // Register Read
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_CTRL:     prdata = {29'd0, reg_ctrl};
            OFF_DIGIT0:   prdata = {24'd0, reg_digit[0]};
            OFF_DIGIT1:   prdata = {24'd0, reg_digit[1]};
            OFF_DIGIT2:   prdata = {24'd0, reg_digit[2]};
            OFF_DIGIT3:   prdata = {24'd0, reg_digit[3]};
            OFF_SCAN_DIV: prdata = {16'd0, reg_scan_div};
            OFF_STATUS:   prdata = {30'd0, current_digit};
            default:      prdata = '0;
        endcase
    end

    // Scan Clock Divider & Digit Sequence
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            scan_counter  <= '0;
            current_digit <= 2'b00;
        end else if (reg_ctrl[0]) begin // Enabled
            if (scan_counter >= reg_scan_div) begin
                scan_counter  <= '0;
                current_digit <= current_digit + 1'b1;
            end else begin
                scan_counter <= scan_counter + 1'b1;
            end
        end else begin
            scan_counter  <= '0;
            current_digit <= 2'b00;
        end
    end

    // BCD-to-7Segment Decoder
    function automatic logic [6:0] bcd_to_7seg(input logic [3:0] bcd);
        case (bcd)
            4'h0: bcd_to_7seg = 7'b0111111; // 0
            4'h1: bcd_to_7seg = 7'b0000110; // 1
            4'h2: bcd_to_7seg = 7'b1011011; // 2
            4'h3: bcd_to_7seg = 7'b1001111; // 3
            4'h4: bcd_to_7seg = 7'b1100110; // 4
            4'h5: bcd_to_7seg = 7'b1101101; // 5
            4'h6: bcd_to_7seg = 7'b1111101; // 6
            4'h7: bcd_to_7seg = 7'b0000111; // 7
            4'h8: bcd_to_7seg = 7'b1111111; // 8
            4'h9: bcd_to_7seg = 7'b1101111; // 9
            4'hA: bcd_to_7seg = 7'b1110111; // A
            4'hb: bcd_to_7seg = 7'b1111100; // b
            4'hC: bcd_to_7seg = 7'b0111001; // C
            4'hd: bcd_to_7seg = 7'b1011110; // d
            4'hE: bcd_to_7seg = 7'b1111001; // E
            4'hF: bcd_to_7seg = 7'b1110001; // F
            default: bcd_to_7seg = 7'b0000000;
        endcase
    endfunction

    // Output multiplexing
    logic [7:0] active_digit_val;
    logic [6:0] decoded_segments;
    logic       active_dp;

    assign active_digit_val = reg_digit[current_digit];
    assign decoded_segments = (reg_ctrl[2]) ? active_digit_val[6:0] : bcd_to_7seg(active_digit_val[3:0]);
    assign active_dp        = active_digit_val[7];

    always_comb begin
        if (!reg_ctrl[0] || reg_ctrl[1]) begin
            // Disabled or Blanked
            seg_out   = 8'h00;
            digit_sel = 4'b0000;
        end else begin
            seg_out   = {active_dp, decoded_segments};
            digit_sel = (4'b0001 << current_digit);
        end
    end

endmodule : apb_seven_seg
