# Clean Machine Setup Guide (GitHub & RISC-V Toolchain)

## 1. GitHub Repository Setup
```bash
git clone https://github.com/Srinivas-Morisetty/soc-sensor-display-veer.git
cd soc-sensor-display-veer
git checkout -b main
```
Use Git Credential Manager (`git config --global credential.helper manager`) or SSH keys for authentication—never store PATs in repository files.

## 2. RISC-V GNU Toolchain Setup (Ubuntu / WSL)
```bash
sudo apt-get update
sudo apt-get install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf make python3
```
Verify installation:
```bash
riscv64-unknown-elf-gcc --version
make -C firmware all
```

## 3. Simulation Tools
- **Vivado XSIM:** Add Vivado `bin/` to `PATH`, then run `run_xsim.bat`.
- **Synopsys VCS:** Source EDA setup script, then run `make sim_all` or `make sim_uvm`.
- **Verilator (Lint):** `sudo apt-get install verilator && make -f Makefile.verilator lint`.
