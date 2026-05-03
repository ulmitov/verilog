# Memory UVM testbench
The DUT is a one port ![memory module](../memory.v) which is used in RISCV implementation.
The testbench verifies 8, 16, 24, 32, 64, and 128 bus widths.
In the deployment actions can view this test suite runnning on **8 to 128** bit busses.


## Test plan

- Stuck bits verification: Consequent write and read back-to-back operations with alternating data bits for all addresses

- Address/Coupling Faults: write in opposite direction of addresses with different block sizes

- Stress pattern test: Write 0x55 and 0xAA to same address then read

- Functionality: Random transactions

- Negative: Read/Write invalid addresses

- Init test: Boot load hex file and read whole memmory



## Design
UVM design with one agent, scoreboard and coverage collector.
The scoreboard uses a two-dimension array variable as a memory Reference model.

![uvm testbench diagram](../tb_uvm_fifo/dir/uvm_diagram.png)

