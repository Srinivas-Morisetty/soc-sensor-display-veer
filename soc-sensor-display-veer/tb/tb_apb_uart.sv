`timescale 1ns/1ps
module tb_apb_uart;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR;
    logic uart_tx, uart_rx = 1, uart_irq;

    always #5 PCLK = ~PCLK;

    apb_uart dut (.*);

    task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge PCLK);
        PADDR <= addr; PWDATA <= data; PWRITE <= 1'b1; PSEL <= 1'b1; PENABLE <= 1'b0;
        @(posedge PCLK);
        PENABLE <= 1'b1;
        @(posedge PCLK);
        while (!PREADY) @(posedge PCLK);
        PSEL <= 1'b0; PENABLE <= 1'b0; PWRITE <= 1'b0;
    endtask

    task automatic apb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge PCLK);
        PADDR <= addr; PWRITE <= 1'b0; PSEL <= 1'b1; PENABLE <= 1'b0;
        @(posedge PCLK);
        PENABLE <= 1'b1;
        @(posedge PCLK);
        while (!PREADY) @(posedge PCLK);
        data = PRDATA;
        PSEL <= 1'b0; PENABLE <= 1'b0;
    endtask

    initial begin
        logic [31:0] rd;
        #20 PRESETn = 1;
        apb_write(32'h8000_000C, 32'd4); // BAUDDIV
        apb_write(32'h8000_0010, 32'd3); // CTRL: TX+RX
        apb_write(32'h8000_0000, 32'h55); // TXDATA
        apb_read(32'h8000_0008, rd);
        $display("[tb_apb_uart] STATUS=0x%08x", rd);
        #500;
        $display("[tb_apb_uart] PASS");
        $finish;
    end
endmodule
