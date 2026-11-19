# Project Proposal: Sensor-Driven Multiplexed Seven-Segment Display SoC

## 1. Problem Statement
Embedded systems frequently need to digitize an analog quantity (temperature, voltage, or distance) and present it on a numeric display without relying on a dedicated display driver IC. This project designs and verifies a compact RISC-V VeeR EL2-based SoC that reads an external 12-bit analog input, converts it to BCD in firmware, and drives a 4-digit multiplexed seven-segment display with PWM-controlled brightness.

## 2. Proposed Architecture & IPs
- **Processor:** CHIPS Alliance RISC-V VeeR EL2 (`RV32IMC`, 4-stage pipeline, AHB-Lite).
- **Memories:** 64 KB ICCM (`0x0000_0000`), 64 KB DCCM (`0x1000_0000`).
- **Baseline Peripherals:** UART (`0x8000_0000`), Timer (`0x8000_1000`), GPIO (`0x8000_2000`).
- **Custom IPs:** Seven-Segment Display Controller (`0x8000_3000`), PWM Generator (`0x8000_4000`), ADC Interface (`0x8000_5000`).

## 3. Verification & Deliverables
- Directed SystemVerilog unit and SoC testbenches (`tb/`).
- UVM verification environment with APB VIP, SVA assertions, and scoreboards (`uvm_tb/`).
- Bare-metal RISC-V C/assembly firmware (`firmware/`).
- Complete documentation, CSV testplans, and architecture/timing diagrams (`docs/`).
