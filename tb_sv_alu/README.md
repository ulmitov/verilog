# ALU SystemVerilog testbench
Design verification of ![alu.sv](../RISCV_SingleCycle/alu.sv) that is used in RISCV implementation.

Two Inputs of 32 bits, 4 bits input for opcode, 32 bits for result.

TODO: expand to 128 bits.


## Testbench design
 - Testbench environment generates transactions and sends them to driver.
 - Driver applies stimulus via interface to the DUT.
 - The monitor passes each transaction to scoreboard.
 - Then, scoreboard compares the received result from ALU with a Reference model ALU result.

![ALU SV testbench diagram](./dir/sv_tb_diagram.png)


## Run with Dsim studio:
```
dvlcom -incdir ../modules/ 'top_tb.sv'
dsim -top work.top_tb -build-all -cs-randc-max 31 +acc+b -code-cov a -waves tb_top_alu.mxd

Coverage report:
dcreport -out_dir dir metrics.db
```


## Run with Verilator (after fix of https://github.com/verilator/verilator/issues/5116):
```
src="../modules/adder.v ../modules/shift.v ../modules/mux.v ../RISCV_SingleCycle/risc_pkg.sv ../RISCV_SingleCycle/alu.sv top_tb.sv"
verilator -Wno-lint -Wno-TIMESCALEMOD --trace --binary --timing -I../modules/ --top top_tb --cc ${src}
./obj_dir/Vtop_tb
```


## Testplan:
 - Boundary values testing for verifying cyclic values of registers (for all ALU operations)
 - Stuck at 1's, stuck at 0's, crosstalk testing (for all ALU operations)
 - Toggling each bit to verify each stage's FF (only for ADD operation)
 - Toggling single random bits to verify each FF (for all ALU operations except ADD)
 - Random transactions to verify functionality (for all ALU operations)
 

# Results:
![ALU log](./dsim.log)

`waves.mxd`
![ALU tb](./waves.png)