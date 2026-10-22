// =============================================================================
// File: apb_gpio.sv
// Description: APB 32-bit General Purpose I/O adhering to Architecture Document Section 5.3.
// Registers:
//   0x00: DATA_OUT [31:0] R/W - Output value for pins configured as outputs
//   0x04: DATA_IN  [31:0] R   - Sampled input value for pins configured as inputs
//   0x08: DIR      [31:0] R/W - Per-pin direction: 1 = output, 0 = input
// =============================================================================

`timescale 1ns/1ps

module apb_gpio #(
    parameter int APB_ADDR_WIDTH = 12,
    parameter int APB_DATA_WIDTH = 32,
    parameter int GPIO_WIDTH     = 32
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

    // GPIO Pad Interfaces
    input  logic [GPIO_WIDTH-1:0]     gpio_i,
    output logic [GPIO_WIDTH-1:0]     gpio_o,
    output logic [GPIO_WIDTH-1:0]     gpio_oe
);

    // Register Offsets
    localparam logic [7:0] OFF_DATA_OUT = 8'h00;
    localparam logic [7:0] OFF_DATA_IN  = 8'h04;
    localparam logic [7:0] OFF_DIR      = 8'h08;

    logic [GPIO_WIDTH-1:0] reg_data_out;
    logic [GPIO_WIDTH-1:0] reg_dir;
    logic [GPIO_WIDTH-1:0] reg_data_in_sync1;
    logic [GPIO_WIDTH-1:0] reg_data_in_sync2;

    assign pready   = 1'b1;
    assign pslverr  = 1'b0;

    assign gpio_o   = reg_data_out;
    assign gpio_oe  = reg_dir;

    logic apb_write_pulse;
    assign apb_write_pulse = psel && penable && pwrite;

    // Two-stage synchronizer for GPIO inputs to eliminate metastability
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_data_in_sync1 <= '0;
            reg_data_in_sync2 <= '0;
        end else begin
            reg_data_in_sync1 <= gpio_i;
            reg_data_in_sync2 <= reg_data_in_sync1;
        end
    end

    // Register Write
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_data_out <= '0;
            reg_dir      <= '0; // all inputs by default
        end else if (apb_write_pulse) begin
            case (paddr[7:0])
                OFF_DATA_OUT: reg_data_out <= pwdata[GPIO_WIDTH-1:0];
                OFF_DIR:      reg_dir      <= pwdata[GPIO_WIDTH-1:0];
                default: ;
            endcase
        end
    end

    // Register Read
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_DATA_OUT: prdata = {{(APB_DATA_WIDTH-GPIO_WIDTH){1'b0}}, reg_data_out};
            OFF_DATA_IN:  prdata = {{(APB_DATA_WIDTH-GPIO_WIDTH){1'b0}}, reg_data_in_sync2};
            OFF_DIR:      prdata = {{(APB_DATA_WIDTH-GPIO_WIDTH){1'b0}}, reg_dir};
            default:      prdata = '0;
        endcase
    end

endmodule : apb_gpio
