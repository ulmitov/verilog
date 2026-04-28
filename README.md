# Contents:

Please navigate to each folder to view the project description Readme

 - ![UART 16550 module](./UART) according to PC16550D spec and a C++ driver which is used in a Verilator testbench
 - ![RISCV implementation](./RISCV_SingleCycle) with some assembly code to check functionality
 - ![SystemVerilog testbench for ALU](./tb_sv_alu)
 - ![UVM testbench for Memory module](./tb_uvm_mem)
 - ![UVM testbench for FIFO](./tb_uvm_fifo)
 - ![modules](./modules) folder includes different verilog modules and their testbenches


# Code coverage:
**Full run log** can be viewed in last deploy run: https://github.com/ulmitov/verilog/actions

**Current status** of verification coverage: https://ulmitov.github.io/verilog/


# Run suites:
- `make regression`: modules testbenches
- `make uart`: UART testbenches
- `make uartcpp`: UART C++ driver tests
- `make riscv`: RISCV testbenches
- `make uvm-fifo`: FIFO UVM testbench
- `make alu`: ALU SystemVerilog testbench
- `make all`: all testbenches


