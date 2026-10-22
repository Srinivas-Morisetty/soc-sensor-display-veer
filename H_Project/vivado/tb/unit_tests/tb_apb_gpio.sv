// =============================================================================
// File: tb_apb_gpio.sv
// Description: Self-Checking Testbench for APB GPIO Unit.
// Verifies:
//   1. Direction register configuration (DIR)
//   2. Output driving (DATA_OUT -> gpio_o)
//   3. Input sampling & 2-stage synchronization (gpio_i -> DATA_IN)
// =============================================================================

`timescale 1ns/1ps

module tb_apb_gpio;

    logic        pclk;
    logic        prstn;
    logic [11:0] paddr;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready;
    logic        pslverr;

    logic [31:0] gpio_i;
    logic [31:0] gpio_o;
    logic [31:0] gpio_oe;

    initial pclk = 0;
    always #10 pclk = ~pclk;

    apb_gpio #(
        .APB_ADDR_WIDTH(12),
        .APB_DATA_WIDTH(32),
        .GPIO_WIDTH(32)
    ) dut (
        .pclk     (pclk),
        .prstn    (prstn),
        .paddr    (paddr),
        .psel     (psel),
        .penable  (penable),
        .pwrite   (pwrite),
        .pwdata   (pwdata),
        .prdata   (prdata),
        .pready   (pready),
        .pslverr  (pslverr),
        .gpio_i   (gpio_i),
        .gpio_o   (gpio_o),
        .gpio_oe  (gpio_oe)
    );

    task automatic apb_write(input [11:0] addr, input [31:0] data);
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b1;
        psel    <= 1'b1;
        penable <= 1'b0;
        pwdata  <= data;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);
        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    task automatic apb_read(input [11:0] addr, output [31:0] data);
        @(posedge pclk);
        paddr   <= addr;
        pwrite  <= 1'b0;
        psel    <= 1'b1;
        penable <= 1'b0;

        @(posedge pclk);
        penable <= 1'b1;

        @(posedge pclk);
        while (!pready) @(posedge pclk);
        data    = prdata;
        psel    <= 1'b0;
        penable <= 1'b0;
    endtask

    int errors = 0;
    logic [31:0] read_val;

    initial begin
        $display("-----------------------------------------------------------------");
        $display("[TEST START] tb_apb_gpio");
        $display("-----------------------------------------------------------------");

        prstn   = 0;
        paddr   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        pwdata  = 0;
        gpio_i  = 32'h1234_5678;
        #40;
        @(posedge pclk);
        prstn   = 1;
        #20;

        // 1. Configure DIR: Lower 16 bits = output (1), Upper 16 bits = input (0)
        apb_write(12'h008, 32'h0000_FFFF);
        #5;
        if (gpio_oe !== 32'h0000_FFFF) begin
            $display("ERROR: gpio_oe mismatch! Got 0x%08h", gpio_oe);
            errors++;
        end

        // 2. Drive DATA_OUT
        apb_write(12'h000, 32'h0000_A5A5);
        #5;
        if (gpio_o !== 32'h0000_A5A5) begin
            $display("ERROR: gpio_o mismatch! Got 0x%08h", gpio_o);
            errors++;
        end

        // 3. Read DATA_IN (wait 3 cycles for synchronizer)
        gpio_i = 32'hCAFE_BABE;
        repeat (4) @(posedge pclk);
        apb_read(12'h004, read_val);
        $display("[CHECK] Sampled DATA_IN = 0x%08h", read_val);
        if (read_val !== 32'hCAFE_BABE) begin
            $display("ERROR: DATA_IN expected 0xCAFE_BABE, got 0x%08h", read_val);
            errors++;
        end

        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_gpio completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_gpio completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_gpio
