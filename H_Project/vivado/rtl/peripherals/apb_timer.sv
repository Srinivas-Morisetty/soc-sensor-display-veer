// =============================================================================
// File: apb_timer.sv
// Description: APB 32-bit Timer conforming to SoC Architecture Document Section 5.2.
// Registers:
//   0x00: COUNT      [31:0]  R     - Current counter value
//   0x04: RELOAD     [31:0]  R/W   - Periodic reload / compare match value
//   0x08: CTRL       [1:0]   R/W   - Bit 0: enable, Bit 1: mode (0=free-running, 1=periodic)
//   0x0C: IRQ_STATUS [0]     R/W1C - Compare-match interrupt flag (Write 1 to clear)
// =============================================================================

`timescale 1ns/1ps

module apb_timer #(
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

    // Interrupt output to PIC
    output logic                      irq_timer
);

    // Register Offsets
    localparam logic [7:0] OFF_COUNT      = 8'h00;
    localparam logic [7:0] OFF_RELOAD     = 8'h04;
    localparam logic [7:0] OFF_CTRL       = 8'h08;
    localparam logic [7:0] OFF_IRQ_STATUS = 8'h0C;

    // Registers
    logic [31:0] reg_count;
    logic [31:0] reg_reload;
    logic [1:0]  reg_ctrl;       // [0]: enable, [1]: mode (0=free-running, 1=periodic)
    logic        reg_irq_status;

    assign pready    = 1'b1;
    assign pslverr   = 1'b0;
    assign irq_timer = reg_irq_status;

    logic apb_write_pulse;
    assign apb_write_pulse = psel && penable && pwrite;

    // Timer Counter Operation
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_count      <= 32'd0;
            reg_reload     <= 32'd0;
            reg_ctrl       <= 2'b00;
            reg_irq_status <= 1'b0;
        end else begin
            // 1. APB Register Writes
            if (apb_write_pulse) begin
                case (paddr[7:0])
                    OFF_RELOAD: reg_reload <= pwdata;
                    OFF_CTRL:   reg_ctrl   <= pwdata[1:0];
                    OFF_IRQ_STATUS: begin
                        if (pwdata[0]) begin
                            reg_irq_status <= 1'b0; // Write 1 to clear
                        end
                    end
                    default: ;
                endcase
            end

            // 2. Timer Counting logic
            if (reg_ctrl[0]) begin // enabled
                if (reg_ctrl[1] == 1'b1) begin // Periodic mode
                    if (reg_count >= reg_reload) begin
                        reg_count      <= 32'd0;
                        reg_irq_status <= 1'b1; // Trigger IRQ on reload match
                    end else begin
                        reg_count <= reg_count + 1'b1;
                    end
                end else begin // Free-running mode
                    reg_count <= reg_count + 1'b1;
                    if (reg_count == reg_reload && reg_reload != 32'd0) begin
                        reg_irq_status <= 1'b1;
                    end
                end
            end
        end
    end

    // APB Read Data Multiplexing
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_COUNT:      prdata = reg_count;
            OFF_RELOAD:     prdata = reg_reload;
            OFF_CTRL:       prdata = {30'd0, reg_ctrl};
            OFF_IRQ_STATUS: prdata = {31'd0, reg_irq_status};
            default:        prdata = '0;
        endcase
    end

endmodule : apb_timer
