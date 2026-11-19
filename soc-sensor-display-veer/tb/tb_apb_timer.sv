`timescale 1ns/1ps
module tb_apb_timer;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR, timer_irq;

    always #5 PCLK = ~PCLK;
    apb_timer dut (.*);

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
        apb_write(32'h8000_1004, 32'd10); // RELOAD
        apb_write(32'h8000_1008, 32'd3);  // Enable + Periodic
        wait(timer_irq == 1'b1);
        apb_read(32'h8000_100C, rd);
        if (rd[0] !== 1'b1) $fatal(1, "Expected IRQ_STATUS=1");
        apb_write(32'h8000_100C, 32'd1); // W1C
        apb_read(32'h8000_100C, rd);
        if (rd[0] !== 1'b0) $fatal(1, "Expected IRQ_STATUS cleared");
        $display("[tb_apb_timer] PASS");
        $finish;
    end
endmodule
