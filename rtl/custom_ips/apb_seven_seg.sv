module apb_seven_seg (
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
    output logic [7:0]  seg_out,
    output logic [3:0]  digit_sel
);
    logic [2:0]  ctrl_reg;
    logic [7:0]  digit_reg [0:3];
    logic [15:0] scan_div_reg;
    logic [15:0] scan_cnt;
    logic [1:0]  active_digit;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    wire wr_en = PSEL && PENABLE && PWRITE;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ctrl_reg     <= 3'd0;
            digit_reg[0] <= 8'd0;
            digit_reg[1] <= 8'd0;
            digit_reg[2] <= 8'd0;
            digit_reg[3] <= 8'd0;
            scan_div_reg <= 16'd0;
            scan_cnt     <= 16'd0;
            active_digit <= 2'd0;
        end else begin
            if (wr_en) begin
                case (PADDR[4:2])
                    3'h0: ctrl_reg     <= PWDATA[2:0];
                    3'h1: digit_reg[0] <= PWDATA[7:0];
                    3'h2: digit_reg[1] <= PWDATA[7:0];
                    3'h3: digit_reg[2] <= PWDATA[7:0];
                    3'h4: digit_reg[3] <= PWDATA[7:0];
                    3'h5: scan_div_reg <= PWDATA[15:0];
                    default: ;
                endcase
            end

            if (ctrl_reg[0]) begin
                if (scan_cnt >= scan_div_reg) begin
                    scan_cnt     <= 16'd0;
                    active_digit <= active_digit + 2'd1;
                end else begin
                    scan_cnt <= scan_cnt + 16'd1;
                end
            end else begin
                scan_cnt     <= 16'd0;
                active_digit <= 2'd0;
            end
        end
    end

    function automatic logic [6:0] bcd_to_7seg(input logic [3:0] bcd);
        case (bcd)
            4'h0: return 7'b0111111;
            4'h1: return 7'b0000110;
            4'h2: return 7'b1011011;
            4'h3: return 7'b1001111;
            4'h4: return 7'b1100110;
            4'h5: return 7'b1101101;
            4'h6: return 7'b1111101;
            4'h7: return 7'b0000111;
            4'h8: return 7'b1111111;
            4'h9: return 7'b1101111;
            4'hA: return 7'b1110111;
            4'hB: return 7'b1111100;
            4'hC: return 7'b0111001;
            4'hD: return 7'b1011110;
            4'hE: return 7'b1111001;
            4'hF: return 7'b1110001;
            default: return 7'b0000000;
        endcase
    endfunction

    logic [7:0] cur_digit_val;
    assign cur_digit_val = digit_reg[active_digit];

    always_comb begin
        if (!ctrl_reg[0] || ctrl_reg[1]) begin
            seg_out   = 8'd0;
            digit_sel = 4'b0000;
        end else begin
            digit_sel = 4'b0001 << active_digit;
            if (ctrl_reg[2])
                seg_out = cur_digit_val; // Raw segment + dp
            else
                seg_out = {cur_digit_val[7], bcd_to_7seg(cur_digit_val[3:0])};
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[4:2])
                3'h0: PRDATA = {29'd0, ctrl_reg};
                3'h1: PRDATA = {24'd0, digit_reg[0]};
                3'h2: PRDATA = {24'd0, digit_reg[1]};
                3'h3: PRDATA = {24'd0, digit_reg[2]};
                3'h4: PRDATA = {24'd0, digit_reg[3]};
                3'h5: PRDATA = {16'd0, scan_div_reg};
                3'h6: PRDATA = {30'd0, active_digit};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
