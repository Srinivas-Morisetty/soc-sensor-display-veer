module apb_uart (
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
    output logic        uart_tx,
    input  logic        uart_rx,
    output logic        uart_irq
);
    logic [15:0] bauddiv;
    logic [1:0]  ctrl;
    logic [7:0]  tx_fifo [0:15];
    logic [3:0]  tx_wr, tx_rd;
    logic [4:0]  tx_cnt;
    logic [7:0]  rx_byte;
    logic        rx_valid;

    logic [15:0] tx_div_cnt;
    logic [3:0]  tx_bit_idx;
    logic [9:0]  tx_shift;
    logic        tx_busy;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;
    assign uart_irq = rx_valid;

    wire wr_en = PSEL && PENABLE && PWRITE;
    wire rd_en = PSEL && PENABLE && !PWRITE;
    wire tx_empty = (tx_cnt == 5'd0) && !tx_busy;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            bauddiv    <= 16'd16;
            ctrl       <= 2'b00;
            tx_wr      <= 4'd0;
            tx_rd      <= 4'd0;
            tx_cnt     <= 5'd0;
            tx_busy    <= 1'b0;
            tx_div_cnt <= 16'd0;
            tx_bit_idx <= 4'd0;
            tx_shift   <= 10'h3FF;
            uart_tx    <= 1'b1;
            rx_byte    <= 8'd0;
            rx_valid   <= 1'b0;
        end else begin
            if (wr_en) begin
                case (PADDR[4:2])
                    3'h0: if (tx_cnt < 5'd16) begin
                        tx_fifo[tx_wr] <= PWDATA[7:0];
                        tx_wr <= tx_wr + 4'd1;
                        tx_cnt <= tx_cnt + 5'd1;
                    end
                    3'h3: bauddiv <= PWDATA[15:0];
                    3'h4: ctrl    <= PWDATA[1:0];
                    default: ;
                endcase
            end

            if (rd_en && PADDR[4:2] == 3'h1) begin
                rx_valid <= 1'b0;
            end

            // Simple TX serializer
            if (ctrl[0]) begin
                if (!tx_busy && tx_cnt > 0) begin
                    tx_shift   <= {1'b1, tx_fifo[tx_rd], 1'b0};
                    tx_rd      <= tx_rd + 4'd1;
                    tx_cnt     <= tx_cnt - 5'd1;
                    tx_busy    <= 1'b1;
                    tx_bit_idx <= 4'd0;
                    tx_div_cnt <= 16'd0;
                end else if (tx_busy) begin
                    uart_tx <= tx_shift[tx_bit_idx];
                    if (tx_div_cnt >= bauddiv) begin
                        tx_div_cnt <= 16'd0;
                        if (tx_bit_idx == 4'd9) begin
                            tx_busy <= 1'b0;
                            uart_tx <= 1'b1;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 4'd1;
                        end
                    end else begin
                        tx_div_cnt <= tx_div_cnt + 16'd1;
                    end
                end
            end else begin
                uart_tx <= 1'b1;
            end
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[4:2])
                3'h1: PRDATA = {24'd0, rx_byte};
                3'h2: PRDATA = {30'd0, rx_valid, tx_empty};
                3'h3: PRDATA = {16'd0, bauddiv};
                3'h4: PRDATA = {30'd0, ctrl};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
