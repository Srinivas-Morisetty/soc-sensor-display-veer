module iccm #(
    parameter int DEPTH_WORDS = 16384 // 64 KB
)(
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        hsel,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP
);
    logic [31:0] mem [0:DEPTH_WORDS-1];
    logic        wr_en_d;
    logic [13:0] wr_addr_d;

    assign HREADY = 1'b1;
    assign HRESP  = 1'b0;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wr_en_d   <= 1'b0;
            wr_addr_d <= 14'd0;
            HRDATA    <= 32'd0;
        end else begin
            if (wr_en_d)
                mem[wr_addr_d] <= HWDATA;

            wr_en_d   <= hsel && HWRITE && (HTRANS == 2'b10 || HTRANS == 2'b11);
            wr_addr_d <= HADDR[15:2];

            if (hsel && !HWRITE && (HTRANS == 2'b10 || HTRANS == 2'b11))
                HRDATA <= mem[HADDR[15:2]];
        end
    end
endmodule
