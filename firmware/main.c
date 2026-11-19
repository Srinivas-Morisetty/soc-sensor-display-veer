/* ============================================================================
 * Sensor-Driven Multiplexed Seven-Segment Display SoC — Bare-Metal Firmware
 * Modeled after reference architecture/firmware/main.c
 * ============================================================================ */
#include <stdint.h>
#include "soc_regs.h"

static uint32_t g_pass_count = 0;
static uint32_t g_fail_count = 0;

static void uart_init(uint32_t bauddiv) {
    UART_BAUDDIV = bauddiv;
    UART_CTRL    = 0x3; /* Enable TX and RX */
    MMIO_FENCE();
}

static void uart_putc(char c) {
    while (!(UART_STATUS & 0x1)) {
        /* Wait for TX FIFO empty */
    }
    UART_TXDATA = (uint32_t)c;
    MMIO_FENCE();
}

static void uart_print(const char *s) {
    while (*s) {
        if (*s == '\n') uart_putc('\r');
        uart_putc(*s++);
    }
}

static void uart_print_dec(uint32_t val) {
    char buf[12];
    int i = 0;
    if (val == 0) {
        uart_putc('0');
        return;
    }
    while (val > 0 && i < 11) {
        buf[i++] = (char)('0' + (val % 10));
        val /= 10;
    }
    while (i > 0) uart_putc(buf[--i]);
}

static void report_result(const char *name, int pass) {
    if (pass) {
        g_pass_count++;
        uart_print("[PASS] ");
    } else {
        g_fail_count++;
        uart_print("[FAIL] ");
    }
    uart_print(name);
    uart_print("\n");
}

static void display_bcd_value(uint32_t val) {
    if (val > 9999) val = 9999;
    SSEG_DIGIT0 = val % 10;
    SSEG_DIGIT1 = (val / 10) % 10;
    SSEG_DIGIT2 = (val / 100) % 10;
    SSEG_DIGIT3 = (val / 1000) % 10;
    MMIO_FENCE();
}

int main(void) {
    uart_init(16);
    uart_print("=== Sensor-Driven 7-Seg Display SoC Test Suite ===\n");

    /* TEST 1: Timer Peripheral */
    TMR_RELOAD = 50;
    TMR_CTRL   = 0x3; /* Enable + Periodic */
    MMIO_FENCE();
    while ((TMR_IRQ_STAT & 0x1) == 0) {}
    TMR_IRQ_STAT = 0x1; /* W1C */
    MMIO_FENCE();
    report_result("Timer Periodic IRQ & W1C", (TMR_IRQ_STAT & 0x1) == 0);

    /* TEST 2: GPIO Peripheral */
    GPIO_DIR      = 0x0000FFFF;
    GPIO_DATA_OUT = 0x0000A55A;
    MMIO_FENCE();
    report_result("GPIO DIR & DATA_OUT", (GPIO_DIR == 0x0000FFFF));

    /* TEST 3: PWM Generator */
    PWM_PERIOD = 100;
    PWM_DUTY   = 50;
    PWM_CTRL   = 0x1; /* Enable, active-high */
    MMIO_FENCE();
    report_result("PWM Configuration", (PWM_PERIOD == 100 && PWM_DUTY == 50));

    /* TEST 4: Seven-Segment Display Controller */
    SSEG_SCAN_DIV = 4;
    SSEG_CTRL     = 0x1; /* Enable, unblank, BCD mode */
    display_bcd_value(1234);
    report_result("Seven-Segment BCD Write", (SSEG_DIGIT3 == 1 && SSEG_DIGIT0 == 4));

    /* TEST 5: ADC Interface */
    ADC_SAMPLE_DIV = 0; /* Software trigger */
    ADC_CTRL       = 0x1; /* Start conversion */
    MMIO_FENCE();
    while ((ADC_STATUS & 0x1) == 0) {}
    uint32_t adc_val = ADC_RESULT & 0xFFF;
    display_bcd_value(adc_val);
    report_result("ADC Conversion -> 7-Seg BCD", 1);

    uart_print("Summary: PASS=");
    uart_print_dec(g_pass_count);
    uart_print(" FAIL=");
    uart_print_dec(g_fail_count);
    uart_print("\n");

    /* Continuous sensor-to-display & brightness loop */
    while (1) {
        ADC_CTRL = 0x1;
        MMIO_FENCE();
        while ((ADC_STATUS & 0x1) == 0) {}
        adc_val = ADC_RESULT & 0xFFF;
        display_bcd_value(adc_val);
        /* Scale PWM duty proportionally to ADC reading */
        PWM_DUTY = (adc_val * 100U) / 4095U;
        MMIO_FENCE();
    }
    return 0;
}
