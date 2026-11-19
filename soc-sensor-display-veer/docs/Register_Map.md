# Complete Hardware Register Specification

## 1. System Memory Architecture & Bus Interconnect
All peripheral registers are 32-bit, word-aligned, and mapped into 4 KB APB windows starting at `0x8000_0000`, decoded by `PADDR[14:12]`. Unmapped accesses return `PSLVERR = 1` / `HRESP = ERROR`.

## 2. System Memory Map Summary
| Slave | Peripheral | Base Address | End Address | Size |
| :--- | :--- | :--- | :--- | :--- |
| - | ICCM (Instruction) | `0x0000_0000` | `0x0000_FFFF` | 64 KB |
| - | DCCM (Data) | `0x1000_0000` | `0x1000_FFFF` | 64 KB |
| 0 | UART | `0x8000_0000` | `0x8000_0FFF` | 4 KB |
| 1 | Timer | `0x8000_1000` | `0x8000_1FFF` | 4 KB |
| 2 | GPIO | `0x8000_2000` | `0x8000_2FFF` | 4 KB |
| 3 | Seven-Segment Display Ctrl | `0x8000_3000` | `0x8000_3FFF` | 4 KB |
| 4 | PWM Generator | `0x8000_4000` | `0x8000_4FFF` | 4 KB |
| 5 | ADC Interface | `0x8000_5000` | `0x8000_5FFF` | 4 KB |

## 3. Slave 0: UART (`0x8000_0000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `TXDATA` | `[7:0]` | W | `0x0` | Byte to transmit (pushes TX FIFO) |
| `0x04` | `RXDATA` | `[7:0]` | R | `0x0` | Received byte (pops RX FIFO) |
| `0x08` | `STATUS` | `[1:0]` | R | `0x1` | `[0]`: TX FIFO empty; `[1]`: RX FIFO not empty |
| `0x0C` | `BAUDDIV` | `[15:0]` | R/W | `0x0` | Clock divider for baud rate |
| `0x10` | `CTRL` | `[1:0]` | R/W | `0x0` | `[0]`: TX enable; `[1]`: RX enable |

## 4. Slave 1: Timer (`0x8000_1000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `COUNT` | `[31:0]` | R | `0x0` | Free-running or periodic counter |
| `0x04` | `RELOAD` | `[31:0]` | R/W | `0x0` | Compare-match / reload value |
| `0x08` | `CTRL` | `[1:0]` | R/W | `0x0` | `[0]`: enable; `[1]`: mode (`0`=free-running, `1`=periodic) |
| `0x0C` | `IRQ_STATUS` | `[0]` | R/W1C | `0x0` | Set on compare-match; write `1` to clear |

## 5. Slave 2: GPIO (`0x8000_2000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `DATA_OUT` | `[31:0]` | R/W | `0x0` | Output value for pins with `DIR[i]=1` |
| `0x04` | `DATA_IN` | `[31:0]` | R | `0x0` | Sampled input value for pins with `DIR[i]=0` |
| `0x08` | `DIR` | `[31:0]` | R/W | `0x0` | Pin direction (`1`=output, `0`=input) |

## 6. Slave 3: Seven-Segment Display Controller (`0x8000_3000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `CTRL` | `[2:0]` | R/W | `0x0` | `[0]`: enable; `[1]`: blank; `[2]`: format (`0`=BCD, `1`=raw) |
| `0x04` | `DIGIT0` | `[7:0]` | R/W | `0x0` | Rightmost digit (`[3:0]` BCD or `[6:0]` raw, `[7]` dp) |
| `0x08` | `DIGIT1` | `[7:0]` | R/W | `0x0` | Digit 1 value |
| `0x0C` | `DIGIT2` | `[7:0]` | R/W | `0x0` | Digit 2 value |
| `0x10` | `DIGIT3` | `[7:0]` | R/W | `0x0` | Leftmost digit value |
| `0x14` | `SCAN_DIV` | `[15:0]` | R/W | `0x0` | Per-digit scan clock divider |
| `0x18` | `STATUS` | `[1:0]` | R | `0x0` | Currently active digit index (`0..3`) |

## 7. Slave 4: PWM Generator (`0x8000_4000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `PERIOD` | `[15:0]` | R/W | `0x0` | PWM period in clock cycles |
| `0x04` | `DUTY` | `[15:0]` | R/W | `0x0` | PWM high-time in clock cycles (`0 <= DUTY <= PERIOD`) |
| `0x08` | `CTRL` | `[1:0]` | R/W | `0x0` | `[0]`: enable; `[1]`: output polarity (`0`=active-high, `1`=inverted) |

## 8. Slave 5: ADC Interface (`0x8000_5000`)
| Offset | Register | Bits | Access | Reset | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `0x00` | `CTRL` | `[0]` | R/W | `0x0` | Start conversion (self-clearing) |
| `0x04` | `STATUS` | `[0]` | R | `0x0` | End-of-conversion flag (`1` when `RESULT` valid) |
| `0x08` | `RESULT` | `[11:0]` | R | `0x0` | Latest 12-bit conversion result |
| `0x0C` | `SAMPLE_DIV` | `[15:0]` | R/W | `0x0` | Auto-sample divider (`0` = software-triggered only) |

## 9. C Firmware Register Header Reference
See [`firmware/soc_regs.h`](../firmware/soc_regs.h) for the complete C macro definitions and `fence` ordering helpers.
