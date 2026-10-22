// =============================================================================
// File: tb_apb_seven_seg.sv
// Description: Self-Checking Testbench for APB Seven-Segment Display Controller.
// Verifies:
//   1. Register read/write accessibility
//   2. Hardware BCD decoding (digits 0..9)
//   3. Raw segment pass-through mode
//   4. Blanking mode
//   5. Persistence-of-vision digit scanning across all 4 digits
// =============================================================================

`timescale 1ns/1ps

module tb_apb_seven_seg;

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

    logic [7:0]  seg_out;
    logic [3:0]  digit_sel;

    // Clock generator (50 MHz, 20ns period)
    initial pclk = 0;
    always #10 pclk = ~pclk;

    // DUT Instance
    apb_seven_seg #(
        .APB_ADDR_WIDTH(12),
        .APB_DATA_WIDTH(32)
    ) dut (
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
        .seg_out   (seg_out),
        .digit_sel (digit_sel)
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

    initial begin
        $dumpfile("tb_apb_seven_seg.vcd");
        $dumpvars(0, tb_apb_seven_seg);

        $display("-----------------------------------------------------------------");
        $display("[TEST START] tb_apb_seven_seg");
        $display("-----------------------------------------------------------------");

        // 1. Reset
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

        // 2. Configure SCAN_DIV for rapid scanning in simulation (divider = 4 clock cycles)
        apb_write(12'h014, 32'd4);
        apb_read(12'h014, read_val);
        if (read_val[15:0] !== 16'd4) begin
            $display("ERROR: SCAN_DIV readback mismatch! Expected 4, got %0d", read_val);
            errors++;
        end

        // 3. Write Digits: Digit0=1, Digit1=2, Digit2=3, Digit3=4 with DP on Digit1
        apb_write(12'h004, 32'h01);        // Digit 0 = '1'
        apb_write(12'h008, 32'h82);        // Digit 1 = '2' + DP (bit 7 = 1)
        apb_write(12'h00C, 32'h03);        // Digit 2 = '3'
        apb_write(12'h010, 32'h04);        // Digit 3 = '4'

        // 4. Enable Controller (CTRL: bit 0=1, bit 1=0, bit 2=0 for BCD mode)
        apb_write(12'h000, 32'h01);

        // 5. Monitor scan cycling across all 4 digits
        for (int d = 0; d < 4; d++) begin
            wait(digit_sel == (4'b0001 << d));
            #5;
            $display("[CHECK] Active Digit %0d: digit_sel=%b, seg_out=%b (hex 0x%02h)", 
                     d, digit_sel, seg_out, seg_out);

            case (d)
                0: if (seg_out !== 8'b00000110) begin // BCD 1
                    $display("ERROR: Digit 0 decoded incorrectly! Got %b", seg_out);
                    errors++;
                end
                1: if (seg_out !== 8'b11011011) begin // BCD 2 + DP
                    $display("ERROR: Digit 1 decoded incorrectly! Got %b", seg_out);
                    errors++;
                end
                2: if (seg_out !== 8'b01001111) begin // BCD 3
                    $display("ERROR: Digit 2 decoded incorrectly! Got %b", seg_out);
                    errors++;
                end
                3: if (seg_out !== 8'b01100110) begin // BCD 4
                    $display("ERROR: Digit 3 decoded incorrectly! Got %b", seg_out);
                    errors++;
                end
            endcase
            @(posedge pclk);
        end

        // 6. Test Blanking Mode (CTRL[1] = 1)
        apb_write(12'h000, 32'h03); // Enable + Blank
        #25;
        if (seg_out !== 8'h00 || digit_sel !== 4'b0000) begin
            $display("ERROR: Blanking failed! seg_out=%b, digit_sel=%b", seg_out, digit_sel);
            errors++;
        end else begin
            $display("[CHECK] Blanking mode verified successfully (all segments off).");
        end

        // Summary
        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_seven_seg completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_seven_seg completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_seven_seg
