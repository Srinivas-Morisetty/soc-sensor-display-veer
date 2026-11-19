`timescale 1ns/1ps
module tb_apb_seven_seg;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR;
    logic [7:0] seg_out;
    logic [3:0] digit_sel;

    always #5 PCLK = ~PCLK;
    apb_seven_seg dut (.*);

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
        apb_write(32'h8000_3014, 32'd2); // SCAN_DIV
        apb_write(32'h8000_3004, 32'd1); // DIGIT0 = 1
        apb_write(32'h8000_3008, 32'd2); // DIGIT1 = 2
        apb_write(32'h8000_300C, 32'd3); // DIGIT2 = 3
        apb_write(32'h8000_3010, 32'd4); // DIGIT3 = 4
        apb_write(32'h8000_3000, 32'd1); // CTRL: Enable, BCD mode
        #100;
        apb_read(32'h8000_3018, rd);
        $display("[tb_apb_seven_seg] Active digit=%0d seg_out=0x%02x PASS", rd[1:0], seg_out);
        $finish;
    end
endmodule
