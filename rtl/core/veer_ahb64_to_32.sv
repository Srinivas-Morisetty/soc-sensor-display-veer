module veer_ahb64_to_32 (
    input  logic [31:0] core_haddr,
    input  logic [63:0] core_hwdata,
    output logic [63:0] core_hrdata,
    output logic [31:0] bus_hwdata,
    input  logic [31:0] bus_hrdata
);
    // Select lower or upper 32-bit lane based on HADDR[2]
    assign bus_hwdata  = core_haddr[2] ? core_hwdata[63:32] : core_hwdata[31:0];
    assign core_hrdata = core_haddr[2] ? {bus_hrdata, 32'd0} : {32'd0, bus_hrdata};
endmodule
