@echo off
rmdir /s /q xsim.dir 2>nul
del /q *.jou *.log *.pb *.wdb *.vcd 2>nul
echo Cleaned simulation artifacts.
