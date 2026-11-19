#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define MMIO_FENCE() __asm__ volatile ("fence" ::: "memory")

/* Peripheral Base Addresses (4 KB APB windows) */
#define UART_BASE      0x80000000UL
#define TIMER_BASE     0x80001000UL
#define GPIO_BASE      0x80002000UL
#define SEVENSEG_BASE  0x80003000UL
#define PWM_BASE       0x80004000UL
#define ADC_BASE       0x80005000UL

/* UART Registers (0x8000_0000) */
#define UART_TXDATA    REG32(UART_BASE + 0x00)
#define UART_RXDATA    REG32(UART_BASE + 0x04)
#define UART_STATUS    REG32(UART_BASE + 0x08)
#define UART_BAUDDIV   REG32(UART_BASE + 0x0C)
#define UART_CTRL      REG32(UART_BASE + 0x10)

/* Timer Registers (0x8000_1000) */
#define TMR_COUNT      REG32(TIMER_BASE + 0x00)
#define TMR_RELOAD     REG32(TIMER_BASE + 0x04)
#define TMR_CTRL       REG32(TIMER_BASE + 0x08)
#define TMR_IRQ_STAT   REG32(TIMER_BASE + 0x0C)

/* GPIO Registers (0x8000_2000) */
#define GPIO_DATA_OUT  REG32(GPIO_BASE + 0x00)
#define GPIO_DATA_IN   REG32(GPIO_BASE + 0x04)
#define GPIO_DIR       REG32(GPIO_BASE + 0x08)

/* Seven-Segment Display Controller Registers (0x8000_3000) */
#define SSEG_CTRL      REG32(SEVENSEG_BASE + 0x00)
#define SSEG_DIGIT0    REG32(SEVENSEG_BASE + 0x04)
#define SSEG_DIGIT1    REG32(SEVENSEG_BASE + 0x08)
#define SSEG_DIGIT2    REG32(SEVENSEG_BASE + 0x0C)
#define SSEG_DIGIT3    REG32(SEVENSEG_BASE + 0x10)
#define SSEG_SCAN_DIV  REG32(SEVENSEG_BASE + 0x14)
#define SSEG_STATUS    REG32(SEVENSEG_BASE + 0x18)

/* PWM Generator Registers (0x8000_4000) */
#define PWM_PERIOD     REG32(PWM_BASE + 0x00)
#define PWM_DUTY       REG32(PWM_BASE + 0x04)
#define PWM_CTRL       REG32(PWM_BASE + 0x08)

/* ADC Interface Registers (0x8000_5000) */
#define ADC_CTRL       REG32(ADC_BASE + 0x00)
#define ADC_STATUS     REG32(ADC_BASE + 0x04)
#define ADC_RESULT     REG32(ADC_BASE + 0x08)
#define ADC_SAMPLE_DIV REG32(ADC_BASE + 0x0C)

#endif /* SOC_REGS_H */
