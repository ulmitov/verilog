# Verification Code coverage:
**Current status** of verification coverage: https://ulmitov.github.io/verilog/

**Full run log** can be viewed in last deploy run: https://github.com/ulmitov/verilog/actions



# Contents:

Each folder has a Readme

 - ![RISCV implementation](./RISCV_SingleCycle) of RV32I and RV64I single cycle and CLINT interrupts block

 - ![RISCV Design verification](./RISCV_SingleCycle/testbench) A Cpp UVM like testbench and assembly application tests

 - ![SystemVerilog testbench for ALU](./tb_sv_alu)

 - ![UVM testbench for Memory module](./tb_uvm_mem)

 - ![UVM testbench for FIFO](./tb_uvm_fifo)

 - ![modules:](./modules) different verilog modules and their testbenches

 - ![UART 16550 module](./UART) according to 16550 spec

 - ![UART C driver](./UART/driver)
 
 - ![UART Cpp testbench](./UART/testbench)



# Run suites:
- `make regression`: modules testbenches
- `make uart`: UART testbenches
- `make uartcpp`: UART C++ driver tests
- `make riscv`: RISCV testbenches
- `make uvm-fifo`: FIFO UVM testbench
- `make uvm-mem`: Memory UVM testbench
- `make alu`: ALU SystemVerilog testbench
- `make riscdv`: RISCV Cpp testbench
- `make all`: all testbenches


