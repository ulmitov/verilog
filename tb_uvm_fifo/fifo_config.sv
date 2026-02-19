`include "uvm_macros.svh"
import uvm_pkg::*;


class fifo_config extends uvm_object;
    // DUT params: compile time constant
    parameter ADDR_WIDTH    = 3;
    parameter DATA_WIDTH    = 8;
    parameter HOLD_TIME     = 1;
	parameter SETUP_TIME    = 2;
    parameter FIFO_DEPTH    = 2**ADDR_WIDTH;
    
    // For printer:
    static int data_width   = DATA_WIDTH;
    static int data_depth   = FIFO_DEPTH;

    // TEST params
    static int FREQ         = 100;              // Mhz
    static int T_CLK        = 1000 / (FREQ *2); // Half cycle ns

    // Sequence params
    static int SEQ_REPEAT   = 100;

    `uvm_object_utils_begin(fifo_config)
        `uvm_field_int(data_width, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(data_depth, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(FREQ, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(T_CLK, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(SEQ_REPEAT, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end
    
    function new(string name = "fifo_config");
        super.new(name);
    endfunction

    virtual function void end_of_elaboration();
        print();
    endfunction
endclass
