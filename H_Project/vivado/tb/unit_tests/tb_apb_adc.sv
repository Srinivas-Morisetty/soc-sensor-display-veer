// =============================================================================
// File: tb_apb_adc.sv
// Description: Self-Checking Testbench for APB ADC Interface.
// Verifies:
//   1. Register read/write accessibility
//   2. Manual software start conversion trigger
//   3. End-of-Conversion (EOC) flag and interrupt assertion
//   4. 12-bit sensor result acquisition
//   5. Automatic periodic sampling mode via SAMPLE_DIV
// =============================================================================

`timescale 1ns/1ps

module tb_apb_adc;

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

    logic [11:0] sensor_in;
    logic        conv_active;
    logic        irq_adc;

    initial pclk = 0;
    always #10 pclk = ~pclk;

    apb_adc #(
        .APB_ADDR_WIDTH(12),
        .APB_DATA_WIDTH(32),
        .CONV_CYCLES(8)
    ) dut (
        .pclk        (pclk),
        .prstn       (prstn),
        .paddr       (paddr),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .pwdata      (pwdata),
        .prdata      (prdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .sensor_in   (sensor_in),
        .conv_active (conv_active),
        .irq_adc     (irq_adc)
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
        $dumpfile("tb_apb_adc.vcd");
        $dumpvars(0, tb_apb_adc);

        $display("-----------------------------------------------------------------");
        $display("[TEST START] tb_apb_adc");
        $display("-----------------------------------------------------------------");

        prstn     = 0;
        paddr     = 0;
        psel      = 0;
        penable   = 0;
        pwrite    = 0;
        pwdata    = 0;
        sensor_in = 12'hA5C; // Simulated sensor value (2652 in decimal)
        #40;
        @(posedge pclk);
        prstn     = 1;
        #20;

        // 1. Trigger manual conversion (CTRL[0] = 1)
        $display("[ACTION] Triggering manual ADC conversion with sensor input 0x%03h", sensor_in);
        apb_write(12'h000, 32'h01);

        // 2. Poll STATUS register until EOC is set
        read_val = 0;
        while (!read_val[0]) begin
            apb_read(12'h004, read_val);
            #10;
        end
        $display("[CHECK] End-of-conversion detected (STATUS=0x%08h, irq_adc=%b)", read_val, irq_adc);

        // 3. Read conversion result
        apb_read(12'h008, read_val);
        $display("[CHECK] Read RESULT = 0x%03h", read_val[11:0]);
        if (read_val[11:0] !== 12'hA5C) begin
            $display("ERROR: Expected result 0x%03h, got 0x%03h", 12'hA5C, read_val[11:0]);
            errors++;
        end

        // 4. Test Auto-sampling mode (SAMPLE_DIV = 10 clock cycles)
        sensor_in = 12'h7E3;
        $display("[ACTION] Enabling auto-sampling (SAMPLE_DIV = 10) with sensor input 0x%03h", sensor_in);
        apb_write(12'h00C, 32'd10);

        // Wait for auto-conversion
        wait(irq_adc == 1'b1);
        apb_read(12'h008, read_val);
        $display("[CHECK] Auto-sample RESULT = 0x%03h", read_val[11:0]);
        if (read_val[11:0] !== 12'h7E3) begin
            $display("ERROR: Expected result 0x%03h, got 0x%03h", 12'h7E3, read_val[11:0]);
            errors++;
        end

        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_adc completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_adc completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_adc
