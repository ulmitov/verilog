# Overview:

- This folder contains common verilog modules which are being used in RISCV, UART, etc..
- Verilog testbenches in `testbench` folder.
- Simulation results in `vcd` folder.
- Some basic synthesys results in `synth` folder.


## How to run:
```
# lint example:
make lint TOP=fifo.v

# run testbench with iverilog:
make vvp TOP=fifo

# run testbench with verilator:
make ver TOP=fifo
```
