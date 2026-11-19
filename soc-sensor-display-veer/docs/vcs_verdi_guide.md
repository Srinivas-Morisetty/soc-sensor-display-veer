# Synopsys VCS & Verdi Simulation Guide

## 1. Compile & Run with FSDB Dumping
```bash
make sim_unit
make sim_soc
```

## 2. Open Waveforms in Verdi (nWave)
Use the pre-configured `.rc` signal files in `waves/` :
```bash
verdi -sv rtl/interconnect/*.sv rtl/ips/*.sv rtl/custom_ips/*.sv rtl/soc_top.sv tb/tb_soc_top.sv -ssf soc_top.fsdb -sswr waves/07_soc_top_wave.rc &
```

### Available `.rc` Signal Templates
- `waves/01_uart_test.rc`
- `waves/02_timer_test.rc`
- `waves/03_gpio_test.rc`
- `waves/04_seven_seg_test.rc`
- `waves/05_pwm_test.rc`
- `waves/06_adc_test.rc`
- `waves/07_soc_top_wave.rc`
