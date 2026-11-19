@echo off
echo === Running Vivado XSIM Unit & SoC Regressions ===
call xvlog -sv rtl/interconnect/*.sv rtl/ips/*.sv rtl/custom_ips/*.sv rtl/core/veer_ahb64_to_32.sv rtl/soc_top.sv tb/*.sv
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%
for %%T in (tb_apb_uart tb_apb_timer tb_apb_gpio tb_apb_seven_seg tb_apb_pwm tb_apb_adc tb_soc_top) do (
    echo --- Elaborating and Running %%T ---
    call xelab %%T -debug typical -s %%T_sim
    call xsim %%T_sim -runall
)
