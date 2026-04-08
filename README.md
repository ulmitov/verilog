# Contents:

Please navigate to each folder to view the project description Readme

 - ![SystemVerilog testbench for ALU](./tb_sv_alu)
 - ![UVM testbench for FIFO](./tb_uvm_fifo)
 - ![UART module](./UART) according to PC16550D spec and a C++ driver which is used in a Verilator testbench
 - ![RISCV implementation](./RISCV_SingleCycle) with some assembly code to check functionality
 - ![modules](./modules) folder includes different verilog modules and their verilog testbenches



# Run regression suites:
- `make regression`: modules testbenches
- `make uart`: UART testbenches
- `make uartcpp`: UART C++ driver testbench
- `make riscv`: RISCV testbenches
- `make all`: all testbenches, except for Fifo UVM and ALU SV suites, which run separately for now (TBD).
