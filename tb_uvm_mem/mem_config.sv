
`include "uvm_macros.svh"
import uvm_pkg::*;
`include "consts.vh"

`ifndef DATA_WIDTH
`define DATA_WIDTH 128
`endif
`ifndef ENDIANESS
`define ENDIANESS 0
`endif


class mem_config extends uvm_object;
    `uvm_object_utils(mem_config)

    parameter DEPTH      = 512;
    parameter ADDR_WIDTH = 32;
    parameter SYNC_READ  = 0;
    parameter ENDIANESS  = `ENDIANESS;
    parameter DATA_WIDTH = `DATA_WIDTH;

    parameter SETUP_TIME = 3;
    parameter HOLD_TIME  = `T_DELAY_FF;

    // TEST params
    static int FREQ         = 100;              // Mhz
    static int T_CLK        = 1000 / (FREQ *2); // Half cycle ns
    static int SEQ_REPEAT   = 100;
    static int BUS_BLOCKS   = DATA_WIDTH / 8;
    `ifdef VERILATOR
    static string MEM_FILE  = "RISCV_SingleCycle/asm/bubble_sort.mem";
    `else
    static string MEM_FILE  = "../RISCV_SingleCycle/asm/bubble_sort.mem";
    `endif

    function new(string name = "mem_config");
        super.new(name);
    endfunction
endclass
