# RISCV single cycle implementation
- Currently supported design is the Base instruction set for **RV32I and RV64I**.
- Zicsr extension
- CLINT module
https://sifive.cdn.prismic.io/sifive/0d163928-2128-42be-a75a-464df65e04e0_sifive-interrupt-cookbook.pdf



##  Testbench files
 - ![Design verification](./testbench) **C++ testbench designed like UVM**: ![See README](./testbench)
 - `alu.sv` is verified in ![**SystemVerilog testbench**](../tb_sv_alu)
 - `memory.sv` is verified in ![**UMV testbench**](../tb_uvm_mem)
 - ![testbench/testbench.sv](./testbench/testbench.sv) is a Verilog application level test which runs assembly code on risc.



## Architecture
![arch.png](./doc/arch.png)



## Design notes
- Separate memories for instructions and data (Harvard architecture)
- Fetch stage reads the current instruction according to the current program counter pointer (PC).
- Decode stage decodes the fields from the instruction bits and passes them to Control block and Register File.
- Register File is the register space of 32x registers, while x0 is the zero reg and all the rest are general purpose.
- ALU unit performs the arithmetics. The inputs to ALU are values from the x-registers or from the immediate value from the instruction. Also the PC is used for branch jump calculations.
- Data Memory serves as a RAM, storing and loading values.
- Branch control unit checks if the program has requested a branch jump of the PC.
- Control block operates all the signals for all other units according to the decoded instruction.
- Lastly, in the high level have to control the PC to point to the next instrucion and to control system reset.

This architecture executes an instruction in one clock cycle.
So the clock frequency should be calculated according to the longest data path.
The ALU unit's add operation takes 3 gate delays per bit.
The longset path commands are load and store.
So depending on the memory type the Tc should be calculated accordingly.

LW loads data from rs1+imm into rd ( `reg[rd] = Mem[reg[rs1]+imm]` ).
SW stores data from rs2 into rs1+imm ( `Mem[reg[rs1]+imm] = reg[rs2]` ).
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


## Run
```
# iverilog:
make risc_tb_arr;   # find max in array asm
make risc_tb_bub;   # bubble sort asm
make risc_tb_fib;   # fibonacci asm

make risc_tb;          # all asm testbenches

make riscdv         # Cpp testbench

# verilator:
make riscver;
```
