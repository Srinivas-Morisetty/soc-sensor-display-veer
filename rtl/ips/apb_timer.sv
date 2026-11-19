module apb_timer (
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
    output logic        timer_irq
);
    logic [31:0] count_reg, reload_reg;
    logic [1:0]  ctrl_reg;
    logic        irq_status;

    assign PREADY    = 1'b1;
    assign PSLVERR   = 1'b0;
    assign timer_irq = irq_status;

    wire wr_en = PSEL && PENABLE && PWRITE;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            count_reg  <= 32'd0;
            reload_reg <= 32'd0;
            ctrl_reg   <= 2'b00;
            irq_status <= 1'b0;
        end else begin
            if (wr_en) begin
                case (PADDR[3:2])
                    2'h1: reload_reg <= PWDATA;
                    2'h2: ctrl_reg   <= PWDATA[1:0];
                    2'h3: if (PWDATA[0]) irq_status <= 1'b0; // W1C
                    default: ;
                endcase
            end

            if (ctrl_reg[0]) begin
                if (count_reg >= reload_reg && reload_reg != 32'd0) begin
                    irq_status <= 1'b1;
                    count_reg  <= ctrl_reg[1] ? 32'd0 : (count_reg + 32'd1);
                end else begin
                    count_reg <= count_reg + 32'd1;
                end
            end
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:2])
                2'h0: PRDATA = count_reg;
                2'h1: PRDATA = reload_reg;
                2'h2: PRDATA = {30'd0, ctrl_reg};
                2'h3: PRDATA = {31'd0, irq_status};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
