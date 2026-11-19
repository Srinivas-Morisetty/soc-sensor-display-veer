module apb_adc (
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
    input  logic [11:0] adc_analog_in,
    output logic        adc_irq
);
    logic        eoc_flag;
    logic [11:0] result_reg;
    logic [15:0] sample_div_reg;
    logic [15:0] sample_cnt;
    logic [3:0]  conv_cnt;
    logic        converting;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;
    assign adc_irq = eoc_flag;

    wire wr_en = PSEL && PENABLE && PWRITE;
    wire rd_en = PSEL && PENABLE && !PWRITE;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            eoc_flag       <= 1'b0;
            result_reg     <= 12'd0;
            sample_div_reg <= 16'd0;
            sample_cnt     <= 16'd0;
            conv_cnt       <= 4'd0;
            converting     <= 1'b0;
        end else begin
            if (wr_en) begin
                case (PADDR[3:2])
                    2'h0: if (PWDATA[0] && !converting) begin
                        converting <= 1'b1;
                        conv_cnt   <= 4'd8;
                        eoc_flag   <= 1'b0;
                    end
                    2'h3: sample_div_reg <= PWDATA[15:0];
                    default: ;
                endcase
            end

            if (rd_en && PADDR[3:2] == 2'h2) begin
                eoc_flag <= 1'b0; // Clear EOC on RESULT read
            end

            if (converting) begin
                if (conv_cnt == 4'd0) begin
                    converting <= 1'b0;
                    result_reg <= adc_analog_in;
                    eoc_flag   <= 1'b1;
                end else begin
                    conv_cnt <= conv_cnt - 4'd1;
                end
            end else if (sample_div_reg != 16'd0) begin
                if (sample_cnt >= sample_div_reg) begin
                    sample_cnt <= 16'd0;
                    converting <= 1'b1;
                    conv_cnt   <= 4'd8;
                end else begin
                    sample_cnt <= sample_cnt + 16'd1;
                end
            end
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:2])
                2'h0: PRDATA = {31'd0, converting};
                2'h1: PRDATA = {31'd0, eoc_flag};
                2'h2: PRDATA = {20'd0, result_reg};
                2'h3: PRDATA = {16'd0, sample_div_reg};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
