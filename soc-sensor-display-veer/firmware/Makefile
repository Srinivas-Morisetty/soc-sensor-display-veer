CROSS_COMPILE ?= riscv64-unknown-elf-
CC      = $(CROSS_COMPILE)gcc
OBJCOPY = $(CROSS_COMPILE)objcopy
OBJDUMP = $(CROSS_COMPILE)objdump

CFLAGS  = -march=rv32imc -mabi=ilp32 -Os -Wall -Wextra -nostdlib -ffreestanding
LDFLAGS = -T link.ld -nostdlib

.PHONY: all clean

all: firmware.elf firmware.hex firmware.dump

firmware.elf: start.S main.c soc_regs.h link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) start.S main.c -o $@

firmware.hex: firmware.elf
	$(OBJCOPY) -O verilog $< $@

firmware.dump: firmware.elf
	$(OBJDUMP) -d $< > $@

clean:
	rm -f firmware.elf firmware.hex firmware.dump *.o
