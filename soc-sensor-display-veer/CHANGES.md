# Changelog

## [1.0.0] - 2026-11-19
### Added
- Reorganized repository structure to match `reference architecture` layout (`docs/`, `firmware/`, `rtl/`, `tb/`, `uvm_tb/`, `scripts/`, `waves/`).
- Added complete `docs/` suite: `Architecture_MicroArchitecture_Spec.md`, `Register_Map.md`, `MEMORY_MAP_ALL_IPS.md`, `IP_SPEC_*.md`, `SOC_VERIFICATION_AND_IP_REPORT.md`, `clean_machine_setup_guide.md`, `Testplan.csv`, and per-IP interface CSVs.
- Added bare-metal RISC-V firmware (`firmware/start.S`, `firmware/link.ld`, `firmware/soc_regs.h`, `firmware/main.c`, `firmware/Makefile`) with VeeR EL2 `mrac` CSR configuration and `fence` ordering.
- Added synthesizable RTL for AHB-Lite/APB bus, ICCM/DCCM, baseline peripherals (UART, Timer, GPIO), and custom IPs (Seven-Segment Display Ctrl, PWM Generator, ADC Interface).
- Added SystemVerilog unit/SoC testbenches (`tb/`), UVM testbenches & APB VIP (`uvm_tb/`), and waveform `.rc` configs (`waves/`).

### Removed
- Consolidated legacy `H_Project/vivado/` layout into the unified top-level structure.
