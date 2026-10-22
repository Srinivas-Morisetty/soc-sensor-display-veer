// =============================================================================
// File: apb_if.sv
// Description: AMBA 3 / 4 APB Interface definition in SystemVerilog.
// Inspired by / aligned with Muneeb Ulla Shariff's APB VIP interface conventions.
// =============================================================================

`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
)(
    input logic pclk,
    input logic prstn
);

    // APB Signal declarations
    logic [ADDR_WIDTH-1:0] paddr;
    logic                  psel;
    logic                  penable;
    logic                  pwrite;
    logic [DATA_WIDTH-1:0] pwdata;
    logic [DATA_WIDTH-1:0] prdata;
    logic                  pready;
    logic                  pslverr;

    // Master Clocking Block
    clocking mdrv_cb @(posedge pclk);
        default input #1step output #1ns;
        output paddr, psel, penable, pwrite, pwdata;
        input  prdata, pready, pslverr;
    endclocking

    // Master Monitor Clocking Block
    clocking mmon_cb @(posedge pclk);
        default input #1step output #1ns;
        input  paddr, psel, penable, pwrite, pwdata, prdata, pready, pslverr;
    endclocking

    // Slave Clocking Block
    clocking sdrv_cb @(posedge pclk);
        default input #1step output #1ns;
        input  paddr, psel, penable, pwrite, pwdata;
        output prdata, pready, pslverr;
    endclocking

    // Slave Monitor Clocking Block
    clocking smon_cb @(posedge pclk);
        default input #1step output #1ns;
        input  paddr, psel, penable, pwrite, pwdata, prdata, pready, pslverr;
    endclocking

    // Modports
    modport master (
        input  pclk, prstn, prdata, pready, pslverr,
        output paddr, psel, penable, pwrite, pwdata
    );

    modport slave (
        input  pclk, prstn, paddr, psel, penable, pwrite, pwdata,
        output prdata, pready, pslverr
    );

    modport master_tb (clocking mdrv_cb, input pclk, prstn);
    modport slave_tb  (clocking sdrv_cb, input pclk, prstn);

endinterface : apb_if

`endif // APB_IF_SV
