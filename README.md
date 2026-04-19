# Contents:

Please navigate to each folder to view the project description Readme

 - ![SystemVerilog testbench for ALU](./tb_sv_alu)
 - ![UVM testbench for FIFO](./tb_uvm_fifo)
 - ![UART module](./UART) according to PC16550D spec and a C++ driver which is used in a Verilator testbench
 - ![RISCV implementation](./RISCV_SingleCycle) with some assembly code to check functionality
 - ![modules](./modules) folder includes different verilog modules and their verilog testbenches


# Code coverage:
Full run log can be viewed in last deploy run under the <ins>"Regression run via Verilator"</ins> step:
[![Verilog CI](https://github.com/ulmitov/verilog/actions/workflows/regression.yml/badge.svg)](https://github.com/ulmitov/verilog/actions/workflows/regression.yml)

**Current status** of verification coverage can be viewed here: https://ulmitov.github.io/verilog/



# Run suites:
- `make regression`: modules testbenches
- `make uart`: UART testbenches
- `make uartcpp`: UART C++ driver testbench
- `make riscv`: RISCV testbenches
- `make all`: all testbenches except for Fifo UVM


