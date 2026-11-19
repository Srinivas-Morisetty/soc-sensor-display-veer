# Architecture, Specification & Micro-Architecture Document
## Sensor-Driven Multiplexed Seven-Segment Display SoC (RISC-V VeeR EL2)

### 1. Introduction of the Project
Embedded systems frequently need to digitize an analog physical quantity and present it on a numeric display without a dedicated display driver IC. This project implements a compact, synthesizable System-on-Chip (SoC) around the **RISC-V VeeR EL2** (`RV32IMC`, 4-stage scalar in-order pipeline) core. The SoC reads an external 12-bit analog input via an ADC Interface, converts it to BCD digits in firmware, drives a 4-digit multiplexed seven-segment display, and controls display brightness via PWM.

### 2. Block Diagrams
#### 2.1 Top-Level SoC Architecture
- **Master:** VeeR EL2 Core (`RV32IMC`), issuing instruction fetches and load/store transactions over AHB-Lite.
- **Interconnect:** AHB-Lite decoder routing `0x0000_0000` (ICCM) and `0x1000_0000` (DCCM) to local memories, and `0x8000_0000`–`0x8000_5FFF` to an AHB-to-APB bridge (`PCLK = HCLK`).
- **Baseline APB Peripherals:** UART (`0x8000_0000`), Timer (`0x8000_1000`), GPIO (`0x8000_2000`).
- **Custom APB Peripherals:** Seven-Segment Display Controller (`0x8000_3000`), PWM Generator (`0x8000_4000`), ADC Interface (`0x8000_5000`).

#### 2.2 Custom IPs Internal Architecture
##### 2.2.1 Seven-Segment Display Controller (`apb_seven_seg`)
- Register bank (`CTRL`, `DIGIT0`–`DIGIT3`, `SCAN_DIV`, `STATUS`).
- Programmable scan-rate divider generating a tick pulse.
- 2-bit active digit counter (`0..3`) driving `digit_sel[3:0]` one-hot.
- Combinational BCD-to-7-segment LUT (active when `CTRL[2]==0`) or raw segment passthrough (`CTRL[2]==1`), with `CTRL[1]` blanking override.

##### 2.2.2 PWM Generator (`apb_pwm`)
- 16-bit free-running counter comparing against `PERIOD` and `DUTY`.
- Output high when `counter < DUTY` (or inverted when `CTRL[1]==1`), gated by `CTRL[0]` enable.

##### 2.2.3 ADC Interface (`apb_adc`)
- Supports software-triggered single conversions (`CTRL[0]` self-clearing) and periodic auto-sampling (`SAMPLE_DIV > 0`).
- Latches 12-bit `RESULT[11:0]`, sets `STATUS[0]` (EOC), and asserts `adc_irq` to the VeeR EL2 PIC.

### 3. Signal List
#### 3.1 External Signals (Chip/Testbench Boundary)
- `clk` (in), `rst_n` (in), `uart_tx` (out), `uart_rx` (in), `gpio_pins[31:0]` (inout), `seg_out[7:0]` (out), `digit_sel[3:0]` (out), `pwm_out` (out), `adc_analog_in[11:0]` (in).

#### 3.2 Core <-> Interconnect Signals (AHB-Lite)
- `HCLK`, `HRESETn`, `HADDR[31:0]`, `HTRANS[1:0]`, `HWRITE`, `HSIZE[2:0]`, `HWDATA[31:0]`, `HRDATA[31:0]`, `HREADY`, `HRESP`.
- *Note:* Native VeeR EL2 AHB-Lite ports are 64-bit (`hrdata[63:0]`, `hwdata[63:0]`); a 64-to-32-bit lane mux/adapter is used when instantiating the full VeeR EL2 RTL.

#### 3.3 AHB-to-APB Bridge & APB Peripheral Bus
- `PCLK` (`= HCLK`), `PRESETn` (`= HRESETn`), `PADDR[31:0]`, `PSEL[5:0]`, `PENABLE`, `PWRITE`, `PWDATA[31:0]`, `PRDATA[31:0]`, `PREADY`, `PSLVERR`.

#### 3.4 Interrupt Signals
- `timer_irq` -> VeeR EL2 PIC `extintsrc_req[1]`
- `adc_irq` -> VeeR EL2 PIC `extintsrc_req[2]`
- `uart_irq` -> VeeR EL2 PIC `extintsrc_req[3]` (optional)

### 4. Control Path of the Project
1. **Boot & Init:** Core resets to `0x0000_0000` (ICCM), `start.S` configures `mrac` CSR (`0x7C0`) so Region 8 (`0x8000_xxxx`) is non-cacheable with side-effects (`0x0002_0000`), initializes `sp` to `0x1001_0000`, zeroes `.bss`, and jumps to `main()`.
2. **Sensor-to-Display Loop:** Firmware triggers `ADC.CTRL[0]=1` (or enables `SAMPLE_DIV`), waits for `ADC.STATUS[0]==1` (or ADC IRQ), reads `ADC.RESULT[11:0]`, converts to 4 BCD digits, and writes `DIGIT0..DIGIT3`, followed by `fence`.
3. **Brightness Control:** Firmware writes `PWM.PERIOD`, `PWM.DUTY`, and `PWM.CTRL[0]=1`.

### 5. Data Path of the Project
- **Analog -> Digital:** `adc_analog_in[11:0]` -> `apb_adc` sample latch -> `RESULT[11:0]` -> APB `PRDATA` -> AHB `HRDATA` -> VeeR EL2 GPR.
- **Digital -> Display:** VeeR EL2 GPR -> AHB `HWDATA` -> APB `PWDATA` -> `apb_seven_seg.DIGITn` -> BCD-to-7-Seg LUT -> `seg_out[7:0]` & `digit_sel[3:0]`.

### 6. Open Items
- Full `Cores-VeeR-EL2` RTL drop-in into `rtl/core/` with 64-to-32-bit AHB-Lite width adapter.
- Physical FPGA pin constraints (`.xdc`) if targeting an FPGA board.
