# Sensor-Driven 7-Seg Display SoC — Verification & Custom IP Report

## 1. Executive Summary
This report documents the verification architecture, directed/UVM testbenches, and bare-metal firmware suite for the Sensor-Driven Multiplexed Seven-Segment Display SoC. All RTL, UVM, and firmware sources are complete and ready for local execution in Vivado XSIM, Synopsys VCS, or Verilator.

## 2. Verification Status Matrix
### 2.1 Hardware RTL Simulation Suites
| Testbench | Target | Key Checks | Execution Status |
| :--- | :--- | :--- | :--- |
| `tb_apb_uart` | `apb_uart` | TX/RX FIFO, baud divider, status flags | Pending local run |
| `tb_apb_timer` | `apb_timer` | Free-running, periodic reload, W1C IRQ | Pending local run |
| `tb_apb_gpio` | `apb_gpio` | 32-bit `DIR`, `DATA_OUT`, `DATA_IN` | Pending local run |
| `tb_apb_seven_seg` | `apb_seven_seg` | BCD LUT, raw mode, blanking, scan mux | Pending local run |
| `tb_apb_pwm` | `apb_pwm` | Period, duty cycle, polarity inversion | Pending local run |
| `tb_apb_adc` | `apb_adc` | SW trigger, auto-sample, 12-bit result, IRQ | Pending local run |
| `tb_soc_top` | `soc_top` | AHB-to-APB decode & end-to-end data path | Pending local run |

### 2.2 UVM Verification Suites
| UVM Environment | Components | Key Checks |
| :--- | :--- | :--- |
| `apb_vip` | Interface + SVA, driver, monitor, sequencer | APB SETUP/ACCESS protocol compliance |
| `seven_seg_uvm_tb` | Env, scoreboard, sequence, test | Digit mux & BCD-to-7-seg reference model |
| `pwm_uvm_tb` | Env, scoreboard, sequence, test | High-time vs. period cycle counting |
| `adc_uvm_tb` | Env, scoreboard, sequence, test | Conversion latency & 12-bit result check |
| `soc_top_uvm_tb` | Top UVM env + virtual sequence | Full-SoC register & datapath regression |

## 3. VeeR EL2 Architectural Considerations
1. **MRAC CSR (`0x7C0`) Configuration:** Region 8 (`0x8000_xxxx`) must be marked non-cacheable with side-effects (`0x0002_0000`) in `firmware/start.S`.
2. **MMIO Ordering:** Per VeeR EL2 PRM Section 2.5.2.3, firmware issues `fence` after memory-mapped register writes.
3. **AHB-Lite Bus Width:** Native VeeR EL2 AHB-Lite ports are 64-bit; a 64-to-32-bit width adapter is required when dropping in the full `Cores-VeeR-EL2` RTL.
