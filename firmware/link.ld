OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    iccm (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    dccm (rwx) : ORIGIN = 0x10000000, LENGTH = 64K
}

SECTIONS
{
    .text :
    {
        *(.text.init)
        *(.text*)
        *(.rodata*)
    } > iccm

    .data :
    {
        . = ALIGN(4);
        *(.data*)
        *(.sdata*)
    } > dccm AT > iccm

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > dccm
}
