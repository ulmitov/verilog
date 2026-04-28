# Memory UVM testbench
The DUT is a one port ![memory module](../memory.v) which is used in RISCV implementation.
The testbench is designed so that it would be possible to verify different bus widths.
In the deployment actions can view this test suite run over **8 to 128** bits busses.


## Test plan
- TODO: Sanity: Check init and read operation, reset test: Init memory with a hex file => then read all bytes per each block_size
- Check stuck 1's: Fill memory with 0x00 => then read each byte
- Check stuck 0's: Fill memory with 0xFF => then read each byte
- Block size test: per each block size do writes and reads. TODO: Switch endianess and repeat test
- Full data width test: write random data using all data bits, then read
- Random transactions. TODO: Repeat for sync read


## Design
UVM design with one agent, scoreboard and coverage collector.
The scoreboard uses a two-dimension array variable as a memory Reference model.
The memory has two types - sync and async read operation.
Also has two modes of endianess.
These modes are tested and can be modified in ![mem_config.sv](./mem_config.sv)

![uvm testbench diagram](../tb_uvm_fifo/dir/uvm_diagram.png)

