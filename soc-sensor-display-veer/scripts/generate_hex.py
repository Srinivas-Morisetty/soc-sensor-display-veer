#!/usr/bin/env python3
"""Convert objcopy verilog hex to 32-bit word hex for ICCM $readmemh."""
import sys

def convert(in_path, out_path):
    with open(in_path, "r") as f:
        lines = [l.strip() for l in f if l.strip() and not l.startswith("@")]
    bytes_list = []
    for line in lines:
        bytes_list.extend(line.split())
    while len(bytes_list) % 4 != 0:
        bytes_list.append("00")
    with open(out_path, "w") as out:
        for i in range(0, len(bytes_list), 4):
            w = bytes_list[i+3] + bytes_list[i+2] + bytes_list[i+1] + bytes_list[i]
            out.write(w + "\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: generate_hex.py <in.hex> <out_words.hex>")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
