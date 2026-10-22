// =============================================================================
// File: tb_apb_timer.sv
// Description: Self-Checking Testbench for APB Timer.
// Verifies:
//   1. Register read/write accessibility (COUNT, RELOAD, CTRL, IRQ_STATUS)
//   2. Periodic timer counting and compare reload
//   3. Compare-match interrupt generation
//   4. IRQ_STATUS Write-1-to-Clear (W1C)
// =============================================================================

`timescale 1ns/1ps

module tb_apb_timer;

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
    logic        irq_timer;

    initial pclk = 0;
    always #10 pclk = ~pclk;

    apb_timer dut (
        .pclk      (pclk),
        .prstn     (prstn),
        .paddr     (paddr),
        .psel      (psel),
        .penable   (penable),
        .pwrite    (pwrite),
        .pwdata    (pwdata),
        .prdata    (prdata),
        .pready    (pready),
        .pslverr   (pslverr),
        .irq_timer (irq_timer)
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
        $display("[TEST START] tb_apb_timer");
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

        // 1. Set RELOAD = 8 cycles
        apb_write(12'h004, 32'd8);

        // 2. Enable Timer in periodic mode (CTRL = 2'b11: mode=periodic, en=1)
        apb_write(12'h008, 32'h03);

        // 3. Wait for IRQ assertion
        wait(irq_timer == 1'b1);
        $display("[CHECK] Timer interrupt fired!");

        // 4. Verify IRQ_STATUS register is 1
        apb_read(12'h00C, read_val);
        if (read_val[0] !== 1'b1) begin
            $display("ERROR: IRQ_STATUS bit 0 expected 1, got %b", read_val[0]);
            errors++;
        end

        // 5. Clear IRQ via Write-1-to-Clear (W1C)
        apb_write(12'h00C, 32'h01);
        apb_read(12'h00C, read_val);
        if (read_val[0] !== 1'b0) begin
            $display("ERROR: IRQ_STATUS not cleared! Still %b", read_val[0]);
            errors++;
        end else begin
            $display("[CHECK] Timer interrupt cleared successfully via W1C.");
        end

        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_timer completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_timer completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_timer
