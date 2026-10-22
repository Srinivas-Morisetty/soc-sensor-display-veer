@echo off
REM =============================================================================
REM Vivado Simulation Runner for Sensor-Driven 7-Segment Display SoC
REM =============================================================================

set VIVADO_BIN=D:\Xilinx\2025.1\Vivado\bin
set XVLOG="%VIVADO_BIN%\xvlog.bat"
set XELAB="%VIVADO_BIN%\xelab.bat"
set XSIM="%VIVADO_BIN%\xsim.bat"

echo =================================================================
echo [1/3] Compiling RTL and Testbench SystemVerilog files in Vivado...
echo =================================================================

call %XVLOG% -sv ^
  vivado/rtl/bus/apb_if.sv ^
  vivado/rtl/bus/ahb_if.sv ^
  vivado/rtl/bus/ahb_to_apb_bridge.sv ^
  vivado/rtl/bus/apb_interconnect.sv ^
  vivado/rtl/peripherals/uart_tx.sv ^
  vivado/rtl/peripherals/uart_rx.sv ^
  vivado/rtl/peripherals/io_generic_fifo.sv ^
  vivado/rtl/peripherals/apb_uart.sv ^
  vivado/rtl/peripherals/apb_timer.sv ^
  vivado/rtl/peripherals/apb_gpio.sv ^
  vivado/rtl/peripherals/apb_seven_seg.sv ^
  vivado/rtl/peripherals/apb_pwm.sv ^
  vivado/rtl/peripherals/apb_adc.sv ^
  vivado/rtl/memory/iccm.sv ^
  vivado/rtl/memory/dccm.sv ^
  vivado/rtl/soc/soc_top.sv ^
  vivado/tb/unit_tests/tb_apb_seven_seg.sv ^
  vivado/tb/unit_tests/tb_apb_pwm.sv ^
  vivado/tb/unit_tests/tb_apb_adc.sv ^
  vivado/tb/unit_tests/tb_apb_timer.sv ^
  vivado/tb/unit_tests/tb_apb_gpio.sv ^
  vivado/tb/unit_tests/tb_apb_uart.sv ^
  vivado/tb/soc_tb/soc_top_tb.sv

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed!
    exit /b %ERRORLEVEL%
)

echo =================================================================
echo [2/3] Elaborating SoC Top-Level Testbench...
echo =================================================================

call %XELAB% -debug typical soc_top_tb -s sim_soc_top

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Elaboration failed!
    exit /b %ERRORLEVEL%
)

echo =================================================================
echo [3/3] Running Full-System Simulation in Vivado xsim...
echo =================================================================

call %XSIM% sim_soc_top -runall

echo =================================================================
echo Done.
echo =================================================================
