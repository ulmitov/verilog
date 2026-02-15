# RISCV Single Cycle implementation

 - TBD: expand to 64 and 128 bits
 - `asm` folder holds the assembly programs and their hex code mem files.
 - `vcd` folder holds the simulation results.
 - `riscv_tb.sv` performs an end to end test of the asm code shown below.



## Run:
```
iverilog -Wall -g2012 -I ../ -o vcd/riscv_tb.vvp -s riscv_tb riscv_tb.sv risc_pkg.sv riscv.sv fetch.sv decode.sv register_file.sv branch_control.sv ../mem.sv alu.sv control.sv ../adder.v ../shift.v ../mux.v
vvp vcd/riscv_tb.vvp
```


##  Testbench files:
 - The end to end assembly test is a Verilog testbench in `riscv_tb.sv`
 - `alu.sv` unit has a **SystemVerilog** testbench in `tb_sv_alu` folder
 - `instruction_mem.sv` unit has a Verilog testbench in `risc_tb.sv`
 - `mem.sv` unit has a Verilog testbench in `mem_tb.v` (in upper dir)
 - `adder.v` and `shift.v` and `mux.v` - all have Verilog testbenches in the upper folder
 - Other RiscV units in this folder do not have dedicated testbenches (for now... TBD)



## bubble_sort.asm
See array values each rf_wr_en
![Bubble sort result](./vcd/bubble_sort_in.png)
See sorted values in reg_file address 0x0B through 0x0E (x11-x14)
![Bubble sort result](./vcd/bubble_sort_out.png)



## fibonacci_sequence.asm
See values each ram.wen in ram.wr_data
![Fibonacci result](./vcd/fibonacci_out.png)



## find_max_in_array.asm
See array values each ram.wen
![Find max result](./vcd/find_max_in_array_in.png)
Wrote max value 2A to ram address 0x18:
![Find max result](./vcd/find_max_in_array_out.png)



## Design:
- Instruction memory acts as a ROM, loading asm code from a file and stores it. Each instruction is 32 bits.
- Fetch unit reads the current instruction according to the current program counter pointer (PC).
- Decode unit decodes the fields from the instruction bits and passes them to Control block and Register File.
- Register File is the register space of 32x registers, while x0 is the zero reg and all the rest are general purpose.
- ALU unit performs the arithmetics. The inputs to ALU are values from the x-registers or from the immediate value from the instruction. Also the PC is used for branch jump calculations.
- Data Memory serves as a RAM, storing and loading values.
- Branch control unit checks if the program has requested a branch jump of the PC.
- Control block operates all the signals for all other units according to the decoded instruction.
- Lastly, in the high level have to control the PC to point to the next instrucion and to control system reset.

This architecture performs an instruction in one clock cycle.
So the clock frequency should be calculated according to the longest data path.
The ALU unit's add operation takes 3 gate delays per bit.
The longset path commands are load and store.
So depending on the memory type the Tc should be calculated accordingly.

LW loads data from rs1+imm into rd ( `rd = M[rs1+imm]` ).
SW stores data from rs2 into rs1+imm ( `M[rs1+imm] = rs2` ).
So max full path time is:
```
LW: tC > tInstFetch(andDecode)_max + tRegFetch_max + tALU_max + tDMemRead_max + tRegWriteBackSetupTime
SW: tC > tInstFetch(andDecode)_max + tRegFetch_max + tALU_max + tDMemWriteSetupTime
```
Also should be aware of hold time violations (although not probable since tC is long enough).
The shortest path is for jal command ( `rd=pc+4; pc+=imm` ). So minimum timing is:
```
th < tInstFetch(andDecode)_min + tALU_min
```
Where th is the minimum hold time either of PC register or RegFile registers.
