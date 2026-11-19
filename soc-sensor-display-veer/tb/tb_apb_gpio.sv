`timescale 1ns/1ps
module tb_apb_gpio;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR;
    logic [31:0] gpio_in = 32'hCAFE_BABE, gpio_out, gpio_oe;

    always #5 PCLK = ~PCLK;
    apb_gpio dut (.*);

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
        apb_write(32'h8000_2008, 32'h0000_FFFF); // DIR
        apb_write(32'h8000_2000, 32'h1234_5678); // DATA_OUT
        if (gpio_oe !== 32'h0000_FFFF || gpio_out !== 32'h1234_5678) $fatal(1, "GPIO out mismatch");
        apb_read(32'h8000_2004, rd);
        if (rd !== 32'hCAFE_BABE) $fatal(1, "GPIO in mismatch");
        $display("[tb_apb_gpio] PASS");
        $finish;
    end
endmodule
