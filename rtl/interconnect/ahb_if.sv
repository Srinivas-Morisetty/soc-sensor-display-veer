interface ahb_if (input logic HCLK, input logic HRESETn);
    logic [31:0] HADDR;
    logic [1:0]  HTRANS;
    logic        HWRITE;
    logic [2:0]  HSIZE;
    logic [31:0] HWDATA;
    logic [31:0] HRDATA;
    logic        HREADY;
    logic        HRESP;

    modport master (
        input  HCLK, HRESETn, HRDATA, HREADY, HRESP,
        output HADDR, HTRANS, HWRITE, HSIZE, HWDATA
    );
    modport slave (
        input  HCLK, HRESETn, HADDR, HTRANS, HWRITE, HSIZE, HWDATA,
        output HRDATA, HREADY, HRESP
    );
endinterface
