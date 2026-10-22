// =============================================================================
// File: apb_pwm.sv
// Description: APB PWM Generator adhering to SoC Architecture Document Section 5.5.
// Registers:
//   0x00: PERIOD [15:0] R/W - Total PWM cycle period in clock cycles
//   0x04: DUTY   [15:0] R/W - High time in clock cycles (0 <= DUTY <= PERIOD)
//   0x08: CTRL   [1:0]  R/W - Bit 0: enable, Bit 1: polarity (0=active-high, 1=inverted)
// =============================================================================

`timescale 1ns/1ps

module apb_pwm #(
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

    // PWM Output line
    output logic                      pwm_out
);

    // Register Offsets
    localparam logic [7:0] OFF_PERIOD = 8'h00;
    localparam logic [7:0] OFF_DUTY   = 8'h04;
    localparam logic [7:0] OFF_CTRL   = 8'h08;

    // Registers
    logic [15:0] reg_period;
    logic [15:0] reg_duty;
    logic [1:0]  reg_ctrl; // [0]: en, [1]: polarity

    // Internal Counter
    logic [15:0] counter;
    logic        raw_pwm;

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    logic apb_write_pulse;
    assign apb_write_pulse = psel && penable && pwrite;

    // Register Writes
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_period <= 16'd1000;
            reg_duty   <= 16'd500;  // 50% duty default
            reg_ctrl   <= 2'b00;    // disabled by default
        end else if (apb_write_pulse) begin
            case (paddr[7:0])
                OFF_PERIOD: reg_period <= pwdata[15:0];
                OFF_DUTY:   reg_duty   <= pwdata[15:0];
                OFF_CTRL:   reg_ctrl   <= pwdata[1:0];
                default: ;
            endcase
        end
    end

    // Register Reads
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_PERIOD: prdata = {16'd0, reg_period};
            OFF_DUTY:   prdata = {16'd0, reg_duty};
            OFF_CTRL:   prdata = {30'd0, reg_ctrl};
            default:    prdata = '0;
        endcase
    end

    // PWM Generation Counter
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            counter <= '0;
        end else if (reg_ctrl[0]) begin
            if (counter >= (reg_period - 1)) begin
                counter <= '0;
            end else begin
                counter <= counter + 1'b1;
            end
        end else begin
            counter <= '0;
        end
    end

    // Combinational PWM waveform generation
    always_comb begin
        if (reg_duty == 16'd0) begin
            raw_pwm = 1'b0;
        end else if (reg_duty >= reg_period) begin
            raw_pwm = 1'b1;
        end else begin
            raw_pwm = (counter < reg_duty);
        end
    end

    // Polarity Selection
    assign pwm_out = reg_ctrl[0] ? (reg_ctrl[1] ? ~raw_pwm : raw_pwm) : 1'b0;

endmodule : apb_pwm
