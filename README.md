# Verification Code coverage:
**Current status** of verification coverage: https://ulmitov.github.io/verilog/

**Full run log** can be viewed in last deploy run: https://github.com/ulmitov/verilog/actions


# Contents:

Each folder has a Readme

 - ![RISCV implementation](./RISCV_SingleCycle) of RV32I and RV64I single cycle and CLINT interrupts block

 - ![RISCV Design verification](./RISCV_SingleCycle/testbench) A C++ UVM like testbench

 - ![SystemVerilog testbench for ALU](./tb_sv_alu)

 - ![UART 16550 module](./UART) according to 16550 spec
 
 - ![UART UVM testbench](./tb_uvm_uart) with RAL model and APB driver

 - ![UART C driver](./UART/driver)
 
 - ![UART C driver validation](./UART/testbench)

 - ![UVM testbench for Memory module](./tb_uvm_mem)

 - ![UVM testbench for FIFO](./tb_uvm_fifo)
 
 - ![modules:](./modules) verilog sub modules and sanity testbenches


# Run suites:
- `make regression`: modules sanity testbenches
- `make uart`: UART testbenches
- `make uartcpp`: UART C++ driver validation
- `make uvm-uart`: UVM UART testbench
- `make uvm-fifo`: UVM FIFO testbench
- `make uvm-mem`: UVM Memory testbench
- `make alu`: SystemVerilog ALU testbench
- `make riscv`: RISCV assembly examples
- `make riscdv`: RISCV C++ testbench
- `make all`: all testbenches


