module apb_gpio (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [31:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe
);
    logic [31:0] data_out_reg, dir_reg;

    assign PREADY   = 1'b1;
    assign PSLVERR  = 1'b0;
    assign gpio_out = data_out_reg;
    assign gpio_oe  = dir_reg;

    wire wr_en = PSEL && PENABLE && PWRITE;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            data_out_reg <= 32'd0;
            dir_reg      <= 32'd0;
        end else if (wr_en) begin
            case (PADDR[3:2])
                2'h0: data_out_reg <= PWDATA;
                2'h2: dir_reg      <= PWDATA;
                default: ;
            endcase
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:2])
                2'h0: PRDATA = data_out_reg;
                2'h1: PRDATA = gpio_in;
                2'h2: PRDATA = dir_reg;
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
