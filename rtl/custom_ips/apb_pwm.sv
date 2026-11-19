module apb_pwm (
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
    output logic        pwm_out
);
    logic [15:0] period_reg, duty_reg, cnt;
    logic [1:0]  ctrl_reg;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    wire wr_en = PSEL && PENABLE && PWRITE;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            period_reg <= 16'd0;
            duty_reg   <= 16'd0;
            ctrl_reg   <= 2'b00;
            cnt        <= 16'd0;
        end else begin
            if (wr_en) begin
                case (PADDR[3:2])
                    2'h0: period_reg <= PWDATA[15:0];
                    2'h1: duty_reg   <= PWDATA[15:0];
                    2'h2: ctrl_reg   <= PWDATA[1:0];
                    default: ;
                endcase
            end

            if (ctrl_reg[0] && period_reg != 16'd0) begin
                if (cnt >= period_reg - 16'd1)
                    cnt <= 16'd0;
                else
                    cnt <= cnt + 16'd1;
            end else begin
                cnt <= 16'd0;
            end
        end
    end

    logic raw_pwm;
    assign raw_pwm = (ctrl_reg[0] && period_reg != 16'd0) ? (cnt < duty_reg) : 1'b0;
    assign pwm_out = ctrl_reg[1] ? ~raw_pwm : raw_pwm;

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:2])
                2'h0: PRDATA = {16'd0, period_reg};
                2'h1: PRDATA = {16'd0, duty_reg};
                2'h2: PRDATA = {30'd0, ctrl_reg};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
