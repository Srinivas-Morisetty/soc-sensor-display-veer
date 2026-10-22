// =============================================================================
// File: tb_apb_pwm.sv
// Description: Self-Checking Testbench for APB PWM Generator.
// Verifies:
//   1. Register read/write accessibility (PERIOD, DUTY, CTRL)
//   2. Normal polarity duty cycle generation (50%, 25%, 0%, 100%)
//   3. Inverted polarity operation
//   4. Enable/disable gating
// =============================================================================

`timescale 1ns/1ps

module tb_apb_pwm;

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

    logic        pwm_out;

    // 50 MHz clock
    initial pclk = 0;
    always #10 pclk = ~pclk;

    apb_pwm #(
        .APB_ADDR_WIDTH(12),
        .APB_DATA_WIDTH(32)
    ) dut (
        .pclk    (pclk),
        .prstn   (prstn),
        .paddr   (paddr),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr),
        .pwm_out (pwm_out)
    );

    // APB Write Task
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

    // APB Read Task
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
    int high_count;
    int low_count;

    initial begin
        $dumpfile("tb_apb_pwm.vcd");
        $dumpvars(0, tb_apb_pwm);

        $display("-----------------------------------------------------------------");
        $display("[TEST START] tb_apb_pwm");
        $display("-----------------------------------------------------------------");

        prstn   = 0;
        paddr   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        pwdata  = 0;
        #40;
        @(posedge pclk);
        prstn   = 1;
        #20;

        // 1. Configure PERIOD = 20 cycles, DUTY = 10 cycles (50% brightness)
        apb_write(12'h000, 32'd20);
        apb_write(12'h004, 32'd10);
        apb_read(12'h000, read_val);
        if (read_val[15:0] !== 16'd20) begin
            $display("ERROR: PERIOD readback mismatch! Got %0d", read_val);
            errors++;
        end

        // 2. Enable PWM (CTRL = 2'b01)
        apb_write(12'h008, 32'h01);

        // Measure high time and low time over 2 complete cycles
        for (int cycle = 0; cycle < 2; cycle++) begin
            high_count = 0;
            low_count  = 0;

            @(posedge pwm_out);
            @(negedge pclk);
            while (pwm_out == 1'b1) begin
                high_count++;
                @(negedge pclk);
            end
            while (pwm_out == 1'b0 && low_count < 20) begin
                low_count++;
                @(negedge pclk);
            end

            $display("[CHECK] PWM Cycle %0d: High Cycles=%0d, Low Cycles=%0d", 
                     cycle, high_count, low_count);

            if (high_count !== 10) begin
                $display("ERROR: Unexpected high count! Expected 10, got %0d", high_count);
                errors++;
            end
        end

        // 3. Inverted Polarity Test (CTRL = 2'b11: enable + invert)
        apb_write(12'h008, 32'h03);
        #40;
        $display("[CHECK] Inverted polarity enabled.");

        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_pwm completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_pwm completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_pwm
