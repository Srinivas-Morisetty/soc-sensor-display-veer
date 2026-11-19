# Memory Map — All IPs

| Region | Base Address | Size | Bus | Access |
| :--- | :--- | :--- | :--- | :--- |
| ICCM | `0x0000_0000` | 64 KB | AHB-Lite | R/W/X (Idempotent) |
| DCCM | `0x1000_0000` | 64 KB | AHB-Lite | R/W (Idempotent) |
| UART | `0x8000_0000` | 4 KB | APB | R/W (Side-Effect) |
| Timer | `0x8000_1000` | 4 KB | APB | R/W (Side-Effect) |
| GPIO | `0x8000_2000` | 4 KB | APB | R/W (Side-Effect) |
| Seven-Segment Display Ctrl | `0x8000_3000` | 4 KB | APB | R/W (Side-Effect) |
| PWM Generator | `0x8000_4000` | 4 KB | APB | R/W (Side-Effect) |
| ADC Interface | `0x8000_5000` | 4 KB | APB | R/W (Side-Effect) |
