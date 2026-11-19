module ahb_to_apb_bridge (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        hsel_apb,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP,

    output logic [31:0] PADDR,
    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [31:0] PWDATA,
    input  logic [31:0] PRDATA,
    input  logic        PREADY,
    input  logic        PSLVERR
);
    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
    state_t state;
    logic        write_q;
    logic [31:0] addr_q;

    wire valid_ahb = hsel_apb && (HTRANS == 2'b10 || HTRANS == 2'b11);

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state   <= IDLE;
            PADDR   <= 32'd0;
            PWRITE  <= 1'b0;
            PWDATA  <= 32'd0;
            addr_q  <= 32'd0;
            write_q <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_ahb) begin
                        addr_q  <= HADDR;
                        write_q <= HWRITE;
                        PADDR   <= HADDR;
                        PWRITE  <= HWRITE;
                        state   <= SETUP;
                    end
                end
                SETUP: begin
                    PWDATA <= HWDATA;
                    state  <= ACCESS;
                end
                ACCESS: begin
                    if (PREADY) begin
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    assign PSEL    = (state == SETUP) || (state == ACCESS);
    assign PENABLE = (state == ACCESS);
    assign HREADY  = (state == IDLE) || (state == ACCESS && PREADY);
    assign HRDATA  = PRDATA;
    assign HRESP   = (state == ACCESS) ? PSLVERR : 1'b0;
endmodule
