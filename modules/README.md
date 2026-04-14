# Overview:

- This folder contains common verilog modules which are being used in RISCV, UART, etc..
- Verilog testbenches in `testbench` folder.
- Simulation results in `vcd` folder.
- Some basic synthesys results in `synth` folder.


## How to run:
```
# lint example:
make lint ARG=fifo.v

# run testbench with iverilog:
make fifo

# run testbench with verilator:
make fifo SIM=v

# or set tb name and source files:
make vvp TOP=fifo_tb SRC="testbench/fifo_tb.v fifo.v"

# run testbench with verilator:
make ver TOP=fifo_tb SRC="testbench/fifo_tb.v fifo.v"
```
