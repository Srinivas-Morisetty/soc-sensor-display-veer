`timescale 1ns/1ps
module tb_soc_top;
    logic        clk = 0, rst_n = 0;
    logic [31:0] haddr = 0, hwdata = 0, hrdata;
    logic [1:0]  htrans = 0;
    logic        hwrite = 0;
    logic [2:0]  hsize = 3'b010;
    logic        hready, hresp;
    logic        uart_tx, uart_rx = 1;
    logic [31:0] gpio_in = 32'h0000_1234, gpio_out, gpio_oe;
    logic [7:0]  seg_out;
    logic [3:0]  digit_sel;
    logic        pwm_out;
    logic [11:0] adc_analog_in = 12'd1234;
    logic        timer_irq, adc_irq, uart_irq;

    always #5 clk = ~clk;

    soc_top dut (.*);

    task automatic ahb_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        while (!hready) @(posedge clk);
        haddr <= addr; htrans <= 2'b10; hwrite <= 1'b1;
        @(posedge clk);
        while (!hready) @(posedge clk);
        htrans <= 2'b00; hwrite <= 1'b0; hwdata <= data;
        @(posedge clk);
        while (!hready) @(posedge clk);
    endtask

    task automatic ahb_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        while (!hready) @(posedge clk);
        haddr <= addr; htrans <= 2'b10; hwrite <= 1'b0;
        @(posedge clk);
        while (!hready) @(posedge clk);
        htrans <= 2'b00;
        @(posedge clk);
        while (!hready) @(posedge clk);
        data = hrdata;
    endtask

    initial begin
        logic [31:0] rd;
        #25 rst_n = 1;

        // 1. Trigger ADC conversion
        ahb_write(32'h8000_5000, 32'd1);
        wait(adc_irq == 1'b1);
        ahb_read(32'h8000_5008, rd);
        $display("[tb_soc_top] ADC RESULT = %0d", rd[11:0]);

        // 2. Drive 7-Seg with BCD digits of 1234
        ahb_write(32'h8000_3014, 32'd2);
        ahb_write(32'h8000_3004, rd[11:0] % 10);
        ahb_write(32'h8000_3008, (rd[11:0] / 10) % 10);
        ahb_write(32'h8000_300C, (rd[11:0] / 100) % 10);
        ahb_write(32'h8000_3010, (rd[11:0] / 1000) % 10);
        ahb_write(32'h8000_3000, 32'd1);

        // 3. Configure PWM brightness
        ahb_write(32'h8000_4000, 32'd20);
        ahb_write(32'h8000_4004, 32'd10);
        ahb_write(32'h8000_4008, 32'd1);

        #200;
        $display("[tb_soc_top] End-to-End SoC Integration PASS");
        $finish;
    end
endmodule
