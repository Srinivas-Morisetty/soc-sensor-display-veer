# Sensor-Driven Multiplexed Seven-Segment Display SoC (SystemVerilog)

This repository implements and verifies the complete RTL System-on-Chip (SoC) based on the RISC-V VeeR EL2 architecture specifications, featuring AMBA AHB-Lite and APB protocols, and tested with **Vivado 2025.1**.

---

## 1. Directory Structure

```text
vivado/
├── fetched_muneeb_src/        # Raw source IPs fetched from Muneeb Ulla Shariff's repo
│   ├── apb_if_vip.sv          # Reference APB interface
│   ├── apb_slave_template.sv  # Reference APB slave FSM
│   ├── af_apb_cip.sv          # SVA assertions
│   ├── apb_uart_pulpino.sv    # Pulpino APB UART
│   ├── uart_tx.sv             # Serial transmitter
│   ├── uart_rx.sv             # Serial receiver
│   ├── uart_interrupt.sv      # UART interrupt generator
│   └── io_generic_fifo.sv     # Parameterized circular FIFO
│
├── rtl/                       # Synthesizable SystemVerilog Design Files
│   ├── bus/
│   │   ├── ahb_if.sv              # AHB-Lite interface (matching VeeR EL2 native bus)
│   │   ├── apb_if.sv              # Standard AMBA APB interface
│   │   ├── ahb_to_apb_bridge.sv   # AHB-Lite to APB protocol converter
│   │   └── apb_interconnect.sv    # 1-to-6 APB address decoder & multiplexer
│   ├── peripherals/
│   │   ├── apb_uart.sv            # [0x8000_0000] UART Controller with TX/RX FIFOs
│   │   ├── apb_timer.sv           # [0x8000_1000] 32-bit Timer with Periodic IRQ
│   │   ├── apb_gpio.sv            # [0x8000_2000] 32-bit GPIO with direction control
│   │   ├── apb_seven_seg.sv       # [0x8000_3000] 4-digit Multiplexed 7-Seg Controller (Custom IP)
│   │   ├── apb_pwm.sv             # [0x8000_4000] PWM Generator for brightness control (Custom IP)
│   │   ├── apb_adc.sv             # [0x8000_5000] 12-bit ADC Interface + Auto-sampler (Custom IP)
│   │   ├── uart_tx.sv             # UART transmitter submodule
│   │   ├── uart_rx.sv             # UART receiver submodule
│   │   └── io_generic_fifo.sv     # Synchronous FIFO submodule
│   ├── memory/
│   │   ├── iccm.sv                # 64 KB Instruction Memory (0x0000_0000)
│   │   └── dccm.sv                # 64 KB Data Memory (0x1000_0000)
│   └── soc/
│       └── soc_top.sv             # Top-Level SoC Integration
│
├── tb/                        # Self-Checking SystemVerilog Testbenches
│   ├── unit_tests/
│   │   ├── tb_apb_seven_seg.sv    # Unit TB for Seven-Segment Controller
│   │   ├── tb_apb_pwm.sv          # Unit TB for PWM Generator
│   │   ├── tb_apb_adc.sv          # Unit TB for ADC Interface
│   │   ├── tb_apb_timer.sv        # Unit TB for Timer
│   │   ├── tb_apb_gpio.sv         # Unit TB for GPIO Unit
│   │   └── tb_apb_uart.sv         # Unit TB for UART Controller (Loopback)
│   └── soc_tb/
│       └── soc_top_tb.sv          # Full End-to-End System Simulation Testbench
│
└── scripts/
    └── run_all_sims.bat           # Automated Vivado xvlog/xelab/xsim runner
```

---

## 2. Memory Map & Register Offsets

| Base Address | Peripheral | Register Offsets & Bitfields |
| :--- | :--- | :--- |
| **`0x0000_0000`** | **ICCM** | 64 KB Instruction Closely-Coupled Memory |
| **`0x1000_0000`** | **DCCM** | 64 KB Data Closely-Coupled Memory |
| **`0x8000_0000`** | **UART** | `0x00`: TXDATA, `0x04`: RXDATA, `0x08`: STATUS, `0x0C`: BAUDDIV, `0x10`: CTRL |
| **`0x8000_1000`** | **Timer** | `0x00`: COUNT, `0x04`: RELOAD, `0x08`: CTRL, `0x0C`: IRQ_STATUS (W1C) |
| **`0x8000_2000`** | **GPIO** | `0x00`: DATA_OUT, `0x04`: DATA_IN, `0x08`: DIR (1=Output, 0=Input) |
| **`0x8000_3000`** | **7-Segment Ctrl** | `0x00`: CTRL, `0x04-0x10`: DIGIT0-3, `0x14`: SCAN_DIV, `0x18`: STATUS |
| **`0x8000_4000`** | **PWM Generator** | `0x00`: PERIOD, `0x04`: DUTY, `0x08`: CTRL (En, Polarity) |
| **`0x8000_5000`** | **ADC Interface** | `0x00`: CTRL (Start), `0x04`: STATUS (EOC), `0x08`: RESULT, `0x0C`: SAMPLE_DIV |

---

## 3. How to Run Simulations in Vivado

Open PowerShell in `H_Project` and execute:
```powershell
.\vivado\scripts\run_all_sims.bat
```
Or run any individual unit test, for example:
```powershell
& "D:\Xilinx\2025.1\Vivado\bin\xelab.bat" -debug typical tb_apb_seven_seg -s sim_seven_seg
& "D:\Xilinx\2025.1\Vivado\bin\xsim.bat" sim_seven_seg -runall
```
