.section .text.init
.global _start

_start:
    /* Disable all interrupts */
    csrw mstatus, zero
    csrw mie, zero

    /* Configure VeeR EL2 MRAC CSR (0x7C0):
       Region 8 (0x8000_0000 - 0x8FFF_FFFF) -> sideeffect=1 (bit 17), cacheable=0 (bit 16)
       Value = 0x0002_0000 */
    li   t0, 0x00020000
    csrw 0x7C0, t0
    fence
    fence.i

    /* Initialize Stack Pointer to top of 64KB DCCM (0x1000_0000 + 0x10000 = 0x1001_0000) */
    li   sp, 0x10010000

    /* Zero .bss section */
    la   t0, _sbss
    la   t1, _ebss
bss_loop:
    bgeu t0, t1, bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    bss_loop
bss_done:

    /* Jump to main */
    call main

1:
    j    1b
