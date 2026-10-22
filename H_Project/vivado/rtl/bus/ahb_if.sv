// =============================================================================
// File: ahb_if.sv
// Description: AMBA 2 AHB-Lite Interface definition in SystemVerilog.
// Interfaces with the RISC-V VeeR EL2 native system bus.
// =============================================================================

`ifndef AHB_IF_SV
`define AHB_IF_SV

interface ahb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic hclk,
    input logic hresetn
);

    // AHB-Lite Transfer Type Parameters
    localparam bit [1:0] HTRANS_IDLE   = 2'b00;
    localparam bit [1:0] HTRANS_BUSY   = 2'b01;
    localparam bit [1:0] HTRANS_NONSEQ = 2'b10;
    localparam bit [1:0] HTRANS_SEQ    = 2'b11;

    // Response Types
    localparam bit       HRESP_OKAY    = 1'b0;
    localparam bit       HRESP_ERROR   = 1'b1;

    // Signals
    logic [ADDR_WIDTH-1:0] haddr;
    logic [1:0]            htrans;
    logic                  hwrite;
    logic [2:0]            hsize;
    logic [2:0]            hburst;
    logic [3:0]            hprot;
    logic [DATA_WIDTH-1:0] hwdata;
    logic [DATA_WIDTH-1:0] hrdata;
    logic                  hready;
    logic                  hreadyout;
    logic                  hresp;

    // Master Modport
    modport master (
        input  hclk, hresetn, hrdata, hready, hresp,
        output haddr, htrans, hwrite, hsize, hburst, hprot, hwdata
    );

    // Slave Modport
    modport slave (
        input  hclk, hresetn, haddr, htrans, hwrite, hsize, hburst, hprot, hwdata, hready,
        output hrdata, hreadyout, hresp
    );

endinterface : ahb_if

`endif // AHB_IF_SV
