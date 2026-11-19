module soc_top (
    input  logic        clk,
    input  logic        rst_n,
    // External AHB-Lite master port (connects to VeeR EL2 core or testbench BFM)
    input  logic [31:0] haddr,
    input  logic [1:0]  htrans,
    input  logic        hwrite,
    input  logic [2:0]  hsize,
    input  logic [31:0] hwdata,
    output logic [31:0] hrdata,
    output logic        hready,
    output logic        hresp,
    // Peripheral external I/O
    output logic        uart_tx,
    input  logic        uart_rx,
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe,
    output logic [7:0]  seg_out,
    output logic [3:0]  digit_sel,
    output logic        pwm_out,
    input  logic [11:0] adc_analog_in,
    // Interrupts to VeeR EL2 PIC
    output logic        timer_irq,
    output logic        adc_irq,
    output logic        uart_irq
);
    logic hsel_iccm, hsel_dccm, hsel_apb;
    assign hsel_iccm = (haddr[31:16] == 16'h0000);
    assign hsel_dccm = (haddr[31:16] == 16'h1000);
    assign hsel_apb  = (haddr[31:16] == 16'h8000);

    logic [31:0] hrdata_iccm, hrdata_dccm, hrdata_apb;
    logic        hready_iccm, hready_dccm, hready_apb;
    logic        hresp_iccm,  hresp_dccm,  hresp_apb;

    iccm u_iccm (
        .HCLK(clk), .HRESETn(rst_n), .hsel(hsel_iccm),
        .HADDR(haddr), .HTRANS(htrans), .HWRITE(hwrite), .HWDATA(hwdata),
        .HRDATA(hrdata_iccm), .HREADY(hready_iccm), .HRESP(hresp_iccm)
    );

    dccm u_dccm (
        .HCLK(clk), .HRESETn(rst_n), .hsel(hsel_dccm),
        .HADDR(haddr), .HTRANS(htrans), .HWRITE(hwrite), .HWDATA(hwdata),
        .HRDATA(hrdata_dccm), .HREADY(hready_dccm), .HRESP(hresp_dccm)
    );

    logic [31:0] paddr, pwdata, prdata;
    logic        psel, penable, pwrite, pready, pslverr;

    ahb_to_apb_bridge u_bridge (
        .HCLK(clk), .HRESETn(rst_n), .hsel_apb(hsel_apb),
        .HADDR(haddr), .HTRANS(htrans), .HWRITE(hwrite), .HWDATA(hwdata),
        .HRDATA(hrdata_apb), .HREADY(hready_apb), .HRESP(hresp_apb),
        .PADDR(paddr), .PSEL(psel), .PENABLE(penable), .PWRITE(pwrite),
        .PWDATA(pwdata), .PRDATA(prdata), .PREADY(pready), .PSLVERR(pslverr)
    );

    // Data-phase slave tracking for AHB read mux
    logic [1:0] slave_sel_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) slave_sel_d <= 2'd0;
        else if (hready) begin
            if (hsel_iccm)      slave_sel_d <= 2'd1;
            else if (hsel_dccm) slave_sel_d <= 2'd2;
            else if (hsel_apb)  slave_sel_d <= 2'd3;
            else                slave_sel_d <= 2'd0;
        end
    end

    always_comb begin
        case (slave_sel_d)
            2'd1: begin hrdata = hrdata_iccm; hready = hready_iccm; hresp = hresp_iccm; end
            2'd2: begin hrdata = hrdata_dccm; hready = hready_dccm; hresp = hresp_dccm; end
            2'd3: begin hrdata = hrdata_apb;  hready = hready_apb;  hresp = hresp_apb;  end
            default: begin hrdata = 32'd0; hready = 1'b1; hresp = 1'b0; end
        endcase
    end

    localparam int NUM_SLAVES = 6;
    logic [NUM_SLAVES-1:0]       psel_s;
    logic [NUM_SLAVES-1:0][31:0] prdata_s;
    logic [NUM_SLAVES-1:0]       pready_s;
    logic [NUM_SLAVES-1:0]       pslverr_s;

    apb_interconnect #(.NUM_SLAVES(NUM_SLAVES)) u_apb_ic (
        .PADDR(paddr), .PSEL(psel), .psel_s(psel_s),
        .prdata_s(prdata_s), .pready_s(pready_s), .pslverr_s(pslverr_s),
        .PRDATA(prdata), .PREADY(pready), .PSLVERR(pslverr)
    );

    apb_uart u_uart (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[0]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[0]), .PREADY(pready_s[0]), .PSLVERR(pslverr_s[0]),
        .uart_tx(uart_tx), .uart_rx(uart_rx), .uart_irq(uart_irq)
    );

    apb_timer u_timer (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[1]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[1]), .PREADY(pready_s[1]), .PSLVERR(pslverr_s[1]),
        .timer_irq(timer_irq)
    );

    apb_gpio u_gpio (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[2]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[2]), .PREADY(pready_s[2]), .PSLVERR(pslverr_s[2]),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe)
    );

    apb_seven_seg u_seven_seg (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[3]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[3]), .PREADY(pready_s[3]), .PSLVERR(pslverr_s[3]),
        .seg_out(seg_out), .digit_sel(digit_sel)
    );

    apb_pwm u_pwm (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[4]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[4]), .PREADY(pready_s[4]), .PSLVERR(pslverr_s[4]),
        .pwm_out(pwm_out)
    );

    apb_adc u_adc (
        .PCLK(clk), .PRESETn(rst_n), .PADDR(paddr), .PSEL(psel_s[5]),
        .PENABLE(penable), .PWRITE(pwrite), .PWDATA(pwdata),
        .PRDATA(prdata_s[5]), .PREADY(pready_s[5]), .PSLVERR(pslverr_s[5]),
        .adc_analog_in(adc_analog_in), .adc_irq(adc_irq)
    );
endmodule
