@echo off
if not exist firmware\firmware.hex (
    echo Build firmware first using: make -C firmware all
    exit /b 1
)
call xvlog -sv rtl/interconnect/*.sv rtl/ips/*.sv rtl/custom_ips/*.sv rtl/core/veer_ahb64_to_32.sv rtl/soc_top.sv tb/tb_soc_top.sv
call xelab tb_soc_top -debug typical -s tb_soc_top_fw_sim
call xsim tb_soc_top_fw_sim -runall
