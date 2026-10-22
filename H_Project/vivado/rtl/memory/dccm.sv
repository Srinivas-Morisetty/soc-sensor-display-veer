// =============================================================================
// File: dccm.sv
// Description: 64 KB Data Closely-Coupled Memory (DCCM) for VeeR EL2.
// Memory Base: 0x1000_0000, Size: 64 KB (16K x 32-bit words).
// Single-cycle AHB-Lite interface. Supports byte/halfword/word read and writes.
// =============================================================================

`timescale 1ns/1ps

module dccm #(
    parameter int ADDR_WIDTH = 16, // 64 KB addressing (16 bits)
    parameter int DATA_WIDTH = 32,
    parameter MEM_FILE       = ""
)(
    input  logic                  hclk,
    input  logic                  hresetn,

    // AHB-Lite Slave Interface
    input  logic [31:0]           haddr,
    input  logic [1:0]            htrans,
    input  logic                  hwrite,
    input  logic [2:0]            hsize,
    input  logic [DATA_WIDTH-1:0] hwdata,
    input  logic                  hsel,
    input  logic                  hready,
    output logic [DATA_WIDTH-1:0] hrdata,
    output logic                  hreadyout,
    output logic                  hresp
);

    localparam int WORDS = 1 << (ADDR_WIDTH - 2); // 16384 words (64 KB)

    // Memory array (4 byte lanes for byte-write capability)
    logic [7:0] mem_b0 [WORDS];
    logic [7:0] mem_b1 [WORDS];
    logic [7:0] mem_b2 [WORDS];
    logic [7:0] mem_b3 [WORDS];

    // AHB transaction detection
    logic trans_valid;
    assign trans_valid = hsel && hready && (htrans == 2'b10 || htrans == 2'b11);

    logic [ADDR_WIDTH-1:2] word_addr_q;
    logic                  write_q;
    logic [2:0]            size_q;
    logic [1:0]            byte_offset_q;

    always_ff @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            word_addr_q   <= '0;
            write_q       <= 1'b0;
            size_q        <= '0;
            byte_offset_q <= '0;
        end else if (trans_valid) begin
            word_addr_q   <= haddr[ADDR_WIDTH-1:2];
            write_q       <= hwrite;
            size_q        <= hsize;
            byte_offset_q <= haddr[1:0];
        end else begin
            write_q <= 1'b0;
        end
    end

    // Generate byte-lane write enables
    logic [3:0] byte_we;
    always_comb begin
        byte_we = 4'b0000;
        if (write_q) begin
            case (size_q)
                3'b000: byte_we[byte_offset_q] = 1'b1; // Byte
                3'b001: begin                          // Halfword
                    if (byte_offset_q[1]) byte_we[3:2] = 2'b11;
                    else                  byte_we[1:0] = 2'b11;
                end
                3'b010: byte_we = 4'b1111;             // Word
                default: byte_we = 4'b1111;
            endcase
        end
    end

    // Synchronous Write
    always_ff @(posedge hclk) begin
        if (byte_we[0]) mem_b0[word_addr_q] <= hwdata[7:0];
        if (byte_we[1]) mem_b1[word_addr_q] <= hwdata[15:8];
        if (byte_we[2]) mem_b2[word_addr_q] <= hwdata[23:16];
        if (byte_we[3]) mem_b3[word_addr_q] <= hwdata[31:24];
    end

    // Single-cycle synchronous Read
    always_ff @(posedge hclk) begin
        if (trans_valid && !hwrite) begin
            hrdata[7:0]   <= mem_b0[haddr[ADDR_WIDTH-1:2]];
            hrdata[15:8]  <= mem_b1[haddr[ADDR_WIDTH-1:2]];
            hrdata[23:16] <= mem_b2[haddr[ADDR_WIDTH-1:2]];
            hrdata[31:24] <= mem_b3[haddr[ADDR_WIDTH-1:2]];
        end
    end

    assign hreadyout = 1'b1;
    assign hresp     = 1'b0; // OKAY

endmodule : dccm
