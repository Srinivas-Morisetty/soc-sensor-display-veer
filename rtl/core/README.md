# RISC-V VeeR EL2 Core Integration (`rtl/core/`)

Place the CHIPS Alliance [Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) RTL (`design/` and generated `snapshots/default_ahb/` config) in this directory.

Use `veer_ahb64_to_32.sv` to adapt VeeR EL2's native 64-bit `lsu_hrdata[63:0]` / `lsu_hwdata[63:0]` AHB-Lite ports to the 32-bit `soc_top` AHB-Lite interconnect.
