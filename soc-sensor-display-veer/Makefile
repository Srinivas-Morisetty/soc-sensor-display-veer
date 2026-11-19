# Master Verification & Build Automation Script
SIM ?= vcs
RTL_SRCS = rtl/interconnect/*.sv rtl/ips/*.sv rtl/custom_ips/*.sv rtl/core/veer_ahb64_to_32.sv rtl/soc_top.sv

.PHONY: all fw sim_unit sim_soc verdi clean

all: fw sim_unit sim_soc

fw:
	$(MAKE) -C firmware all

sim_unit:
	@for tb in tb/tb_apb_uart.sv tb/tb_apb_timer.sv tb/tb_apb_gpio.sv tb/tb_apb_seven_seg.sv tb/tb_apb_pwm.sv tb/tb_apb_adc.sv; do \
		echo "=== Running $$tb ==="; \
		vcs -sverilog -full64 -debug_access+all -kdb -timescale=1ns/1ps $(RTL_SRCS) $$tb -o simv_unit && ./simv_unit; \
	done

sim_soc:
	vcs -sverilog -full64 -debug_access+all -kdb -timescale=1ns/1ps $(RTL_SRCS) tb/tb_soc_top.sv -o simv_soc
	./simv_soc

verdi:
	verdi -sv $(RTL_SRCS) tb/tb_soc_top.sv -ssf soc_top.fsdb -sswr waves/07_soc_top_wave.rc &

clean:
	rm -rf simv* csrc DVEfiles verdiLog novas.* *.log *.vcd *.fsdb obj_dir
	$(MAKE) -C firmware clean
