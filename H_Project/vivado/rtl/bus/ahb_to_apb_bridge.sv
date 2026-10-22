// =============================================================================
// File: ahb_to_apb_bridge.sv
// Description: AHB-Lite to APB Bridge in SystemVerilog.
// Converts AHB-Lite pipelined transfers from VeeR EL2 core into APB 2-phase transfers.
// Supports wait-state extension via PREADY and error propagation via PSLVERR/HRESP.
// =============================================================================

`timescale 1ns/1ps

module ahb_to_apb_bridge #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    // Clock and Reset
    input  logic                  hclk,
    input  logic                  hresetn,

    // AHB-Lite Slave Interface
    input  logic [ADDR_WIDTH-1:0] haddr,
    input  logic [1:0]            htrans,
    input  logic                  hwrite,
    input  logic [2:0]            hsize,
    input  logic [DATA_WIDTH-1:0] hwdata,
    input  logic                  hsel,
    input  logic                  hready,
    output logic [DATA_WIDTH-1:0] hrdata,
    output logic                  hreadyout,
    output logic                  hresp,

    // APB Master Interface
    output logic [ADDR_WIDTH-1:0] paddr,
    output logic                  psel,
    output logic                  penable,
    output logic                  pwrite,
    output logic [DATA_WIDTH-1:0] pwdata,
    input  logic [DATA_WIDTH-1:0] prdata,
    input  logic                  pready,
    input  logic                  pslverr
);

    localparam bit [1:0] HTRANS_IDLE   = 2'b00;
    localparam bit [1:0] HTRANS_BUSY   = 2'b01;
    localparam bit [1:0] HTRANS_NONSEQ = 2'b10;
    localparam bit [1:0] HTRANS_SEQ    = 2'b11;

    typedef enum logic [1:0] {
        ST_IDLE   = 2'b00,
        ST_SETUP  = 2'b01,
        ST_ACCESS = 2'b10
    } bridge_state_t;

    bridge_state_t state_q, state_d;

    // Registered AHB transfer attributes
    logic [ADDR_WIDTH-1:0] addr_q;
    logic                  write_q;
    logic [2:0]            size_q;
    logic [DATA_WIDTH-1:0] wdata_q;

    // Detect valid incoming AHB transaction
    logic ahb_transfer_valid;
    assign ahb_transfer_valid = hsel && hready && (htrans == HTRANS_NONSEQ || htrans == HTRANS_SEQ);

    always_ff @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            state_q <= ST_IDLE;
            addr_q  <= '0;
            write_q <= 1'b0;
            size_q  <= '0;
            wdata_q <= '0;
        end else begin
            state_q <= state_d;
            if (state_q == ST_IDLE && ahb_transfer_valid) begin
                addr_q  <= haddr;
                write_q <= hwrite;
                size_q  <= hsize;
            end
            if (state_q == ST_SETUP) begin
                wdata_q <= hwdata;
            end
        end
    end

    // Next-state logic & APB control
    always_comb begin
        state_d   = state_q;
        psel      = 1'b0;
        penable   = 1'b0;
        paddr     = addr_q;
        pwrite    = write_q;
        pwdata    = (state_q == ST_SETUP) ? hwdata : wdata_q;
        hreadyout = 1'b1;
        hresp     = 1'b0; // 0 = OKAY
        hrdata    = prdata;

        case (state_q)
            ST_IDLE: begin
                hreadyout = 1'b1;
                if (ahb_transfer_valid) begin
                    state_d   = ST_SETUP;
                    hreadyout = 1'b0; // hold AHB master until transfer finishes
                end
            end

            ST_SETUP: begin
                psel      = 1'b1;
                penable   = 1'b0;
                hreadyout = 1'b0;
                state_d   = ST_ACCESS;
            end

            ST_ACCESS: begin
                psel    = 1'b1;
                penable = 1'b1;

                if (pready) begin
                    hreadyout = 1'b1;
                    hresp     = pslverr;
                    hrdata    = prdata;
                    state_d   = ST_IDLE;
                end else begin
                    hreadyout = 1'b0;
                    state_d   = ST_ACCESS; // wait state
                end
            end

            default: state_d = ST_IDLE;
        endcase
    end

endmodule : ahb_to_apb_bridge
