`timescale 1ns/1ps
module tb_apb_pwm;
    logic PCLK = 0, PRESETn = 0;
    logic [31:0] PADDR = 0, PWDATA = 0, PRDATA;
    logic PSEL = 0, PENABLE = 0, PWRITE = 0, PREADY, PSLVERR, pwm_out;

    always #5 PCLK = ~PCLK;
    apb_pwm dut (.*);

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
        int high_cnt = 0;
        #20 PRESETn = 1;
        apb_write(32'h8000_4000, 32'd10); // PERIOD = 10
        apb_write(32'h8000_4004, 32'd3);  // DUTY = 3
        apb_write(32'h8000_4008, 32'd1);  // CTRL = enable
        repeat (10) begin
            @(posedge PCLK);
            if (pwm_out) high_cnt++;
        end
        if (high_cnt != 3) $fatal(1, "Expected 3 high cycles, got %0d", high_cnt);
        $display("[tb_apb_pwm] PASS (high_cnt=%0d/10)", high_cnt);
        $finish;
    end
endmodule
