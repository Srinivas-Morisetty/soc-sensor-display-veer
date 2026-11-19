`timescale 1ns/1ps
module tb_apb_adc;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR;
    logic [11:0] adc_analog_in = 12'hA5A;
    logic adc_irq;

    always #5 PCLK = ~PCLK;
    apb_adc dut (.*);

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
        apb_write(32'h8000_5000, 32'd1); // Start conversion
        wait(adc_irq == 1'b1);
        apb_read(32'h8000_5008, rd);
        if (rd[11:0] !== 12'hA5A) $fatal(1, "ADC mismatch: got 0x%03x", rd[11:0]);
        $display("[tb_apb_adc] PASS (RESULT=0x%03x)", rd[11:0]);
        $finish;
    end
endmodule
