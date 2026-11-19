module apb_interconnect #(
    parameter int NUM_SLAVES = 6
)(
    input  logic [31:0]             PADDR,
    input  logic                    PSEL,
    output logic [NUM_SLAVES-1:0]   psel_s,
    input  logic [NUM_SLAVES-1:0][31:0] prdata_s,
    input  logic [NUM_SLAVES-1:0]   pready_s,
    input  logic [NUM_SLAVES-1:0]   pslverr_s,
    output logic [31:0]             PRDATA,
    output logic                    PREADY,
    output logic                    PSLVERR
);
    logic [2:0] slave_idx;
    assign slave_idx = PADDR[14:12];

    always_comb begin
        psel_s  = '0;
        PRDATA  = 32'd0;
        PREADY  = 1'b1;
        PSLVERR = 1'b0;
        if (PSEL) begin
            if (PADDR[31:15] == 17'h10000 && slave_idx < NUM_SLAVES) begin
                psel_s[slave_idx] = 1'b1;
                PRDATA  = prdata_s[slave_idx];
                PREADY  = pready_s[slave_idx];
                PSLVERR = pslverr_s[slave_idx];
            end else begin
                PSLVERR = 1'b1;
            end
        end
    end
endmodule
