# IP Specification: PWM Generator (`apb_pwm`)
- **Base Address:** `0x8000_4000` (4 KB APB window)
- **Function:** Generates a programmable duty-cycle PWM waveform on `pwm_out` for display brightness or indicator LEDs.
- **Operation:** When `CTRL[0]=1` and `PERIOD > 0`, internal 16-bit counter counts `0 .. PERIOD-1`. Raw output is `1` while `counter < DUTY`, optionally inverted by `CTRL[1]`.
