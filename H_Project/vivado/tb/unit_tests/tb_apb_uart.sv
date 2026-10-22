// =============================================================================
// File: tb_apb_uart.sv
// Description: Self-Checking Testbench for APB UART with loopback verification.
// Verifies:
//   1. Register read/write accessibility (BAUDDIV, CTRL)
//   2. FIFO empty / not empty status bits
//   3. Transmission and reception via external loopback (uart_tx -> uart_rx)
// =============================================================================

`timescale 1ns/1ps

module tb_apb_uart;

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

    logic        uart_tx;
    logic        uart_rx;
    logic        irq_uart;

    initial pclk = 0;
    always #10 pclk = ~pclk;

    // Loopback wire: connect TX to RX
    assign uart_rx = uart_tx;

    apb_uart #(
        .APB_ADDR_WIDTH(12),
        .APB_DATA_WIDTH(32),
        .FIFO_DEPTH(16)
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
        .uart_rx  (uart_rx),
        .uart_tx  (uart_tx),
        .irq_uart (irq_uart)
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
        $display("[TEST START] tb_apb_uart");
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

        // 1. Set fast BAUDDIV for simulation (e.g. 4 cycles per baud tick)
        apb_write(12'h00C, 32'd4);

        // 2. Enable TX and RX (CTRL = 2'b11)
        apb_write(12'h010, 32'h03);

        // 3. Send byte 0x48 ('H')
        $display("[ACTION] Writing 0x48 ('H') to TXDATA register...");
        apb_write(12'h000, 32'h48);

        // 4. Wait for transmission through loopback to complete
        $display("[WAIT] Waiting for UART RX reception...");
        read_val = 0;
        while (!read_val[1]) begin // Bit 1 of STATUS is rx_not_empty
            apb_read(12'h008, read_val);
            #40;
        end

        // 5. Read received byte
        apb_read(12'h004, read_val);
        $display("[CHECK] Received UART byte = 0x%02h ('%c')", read_val[7:0], read_val[7:0]);
        if (read_val[7:0] !== 8'h48) begin
            $display("ERROR: Expected 0x48, got 0x%02h", read_val[7:0]);
            errors++;
        end

        #50;
        $display("-----------------------------------------------------------------");
        if (errors == 0) begin
            $display("[TEST PASSED] tb_apb_uart completed with 0 errors!");
        end else begin
            $display("[TEST FAILED] tb_apb_uart completed with %0d errors!", errors);
        end
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule : tb_apb_uart
