// =============================================================================
// File: apb_adc.sv
// Description: APB 12-bit ADC Interface with automatic sampling and conversion logic.
// Conforms to SoC Architecture Document Section 5.6.
//
// Registers:
//   0x00: CTRL       [0]    R/W - Bit 0: start conversion (self-clearing)
//   0x04: STATUS     [0]    R   - Bit 0: end-of-conversion (EOC) flag; 1 when RESULT valid
//   0x08: RESULT     [11:0] R   - Latest 12-bit conversion result
//   0x0C: SAMPLE_DIV [15:0] R/W - Auto sample rate divider (0 = manual trigger only)
// =============================================================================

`timescale 1ns/1ps

module apb_adc #(
    parameter int APB_ADDR_WIDTH = 12,
    parameter int APB_DATA_WIDTH = 32,
    parameter int CONV_CYCLES    = 16   // Conversion latency in clock cycles
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

    // Sensor / Analog Model Input
    input  logic [11:0]               sensor_in,
    output logic                      conv_active,

    // Interrupt output to PIC
    output logic                      irq_adc
);

    // Register Offsets
    localparam logic [7:0] OFF_CTRL       = 8'h00;
    localparam logic [7:0] OFF_STATUS     = 8'h04;
    localparam logic [7:0] OFF_RESULT     = 8'h08;
    localparam logic [7:0] OFF_SAMPLE_DIV = 8'h0C;

    // Registers
    logic        reg_ctrl_start;
    logic        reg_status_eoc;
    logic [11:0] reg_result;
    logic [15:0] reg_sample_div;

    // Conversion state machine
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        CONVERT   = 2'b01,
        COMPLETE  = 2'b10
    } adc_fsm_t;

    adc_fsm_t fsm_state;
    logic [7:0]  conv_timer;
    logic [15:0] auto_sample_counter;

    assign pready      = 1'b1;
    assign pslverr     = 1'b0;
    assign irq_adc     = reg_status_eoc;
    assign conv_active = (fsm_state == CONVERT);

    logic apb_write_pulse;
    assign apb_write_pulse = psel && penable && pwrite;

    // APB Writes
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            reg_ctrl_start <= 1'b0;
            reg_sample_div <= 16'd0;
        end else begin
            reg_ctrl_start <= 1'b0; // Self-clearing start bit
            if (apb_write_pulse) begin
                case (paddr[7:0])
                    OFF_CTRL:       reg_ctrl_start <= pwdata[0];
                    OFF_SAMPLE_DIV: reg_sample_div <= pwdata[15:0];
                    default: ;
                endcase
            end
        end
    end

    // APB Reads
    always_comb begin
        prdata = '0;
        case (paddr[7:0])
            OFF_CTRL:       prdata = {31'd0, reg_ctrl_start};
            OFF_STATUS:     prdata = {31'd0, reg_status_eoc};
            OFF_RESULT:     prdata = {20'd0, reg_result};
            OFF_SAMPLE_DIV: prdata = {16'd0, reg_sample_div};
            default:        prdata = '0;
        endcase
    end

    // Auto-sample trigger counter
    logic auto_trigger;
    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            auto_sample_counter <= '0;
            auto_trigger        <= 1'b0;
        end else if (reg_sample_div > 16'd0) begin
            if (auto_sample_counter >= reg_sample_div) begin
                auto_sample_counter <= '0;
                auto_trigger        <= 1'b1;
            end else begin
                auto_sample_counter <= auto_sample_counter + 1'b1;
                auto_trigger        <= 1'b0;
            end
        end else begin
            auto_sample_counter <= '0;
            auto_trigger        <= 1'b0;
        end
    end

    // Conversion FSM
    logic read_result_pulse;
    assign read_result_pulse = psel && penable && !pwrite && (paddr[7:0] == OFF_RESULT);

    always_ff @(posedge pclk or negedge prstn) begin
        if (!prstn) begin
            fsm_state      <= IDLE;
            conv_timer     <= '0;
            reg_status_eoc <= 1'b0;
            reg_result     <= 12'd0;
        end else begin
            if (read_result_pulse) begin
                reg_status_eoc <= 1'b0;
            end

            case (fsm_state)
                IDLE: begin
                    if (reg_ctrl_start || auto_trigger) begin
                        fsm_state      <= CONVERT;
                        conv_timer     <= '0;
                        reg_status_eoc <= 1'b0;
                    end
                end

                CONVERT: begin
                    if (conv_timer >= (CONV_CYCLES - 1)) begin
                        fsm_state      <= COMPLETE;
                        reg_result     <= sensor_in; // Sample digitized sensor value
                        reg_status_eoc <= 1'b1;     // Set EOC flag
                    end else begin
                        conv_timer <= conv_timer + 1'b1;
                    end
                end

                COMPLETE: begin
                    fsm_state <= IDLE;
                end

                default: fsm_state <= IDLE;
            endcase
        end
    end

endmodule : apb_adc
