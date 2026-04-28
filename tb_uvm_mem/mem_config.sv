
`include "uvm_macros.svh"
import uvm_pkg::*;
import risc_pkg::op_enum_dmem_size;
`include "consts.vh"

`ifndef DATA_WIDTH
`define DATA_WIDTH 32
`endif


class mem_config extends uvm_object;
    `uvm_object_utils(mem_config)

    parameter MEM_FILE   = "";
    parameter ADDR_WIDTH = 32;
    parameter SYNC_READ  = 0;
    parameter ENDIANESS  = 0;
    parameter DEPTH      = 512;
    parameter DATA_WIDTH = `DATA_WIDTH;

    parameter SETUP_TIME = 3;
    parameter HOLD_TIME = `T_DELAY_FF;

    // TEST params
    static int FREQ         = 100;              // Mhz
    static int T_CLK        = 1000 / (FREQ *2); // Half cycle ns
    static int SEQ_REPEAT   = 100;

    function new(string name = "mem_config");
        super.new(name);
    endfunction
endclass
