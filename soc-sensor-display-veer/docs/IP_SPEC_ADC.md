# IP Specification: ADC Interface (`apb_adc`)
- **Base Address:** `0x8000_5000` (4 KB APB window)
- **Function:** Interfaces a 12-bit ADC / behavioral analog stimulus (`adc_analog_in[11:0]`) to the APB bus.
- **Operation:** Writing `CTRL[0]=1` starts a conversion (self-clearing). Setting `SAMPLE_DIV > 0` triggers periodic conversions automatically. Upon completion, `RESULT[11:0]` updates, `STATUS[0]` asserts, and `adc_irq` is raised.
