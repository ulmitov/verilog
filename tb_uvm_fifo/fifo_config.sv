`include "uvm_macros.svh"
import uvm_pkg::*;


class fifo_config extends uvm_object;
    // DUT params: compile time constant
    parameter ADDR_WIDTH    = 3;
    parameter DATA_WIDTH    = 8;
    parameter HOLD_TIME     = 2;
	parameter SETUP_TIME    = 3;
    parameter FIFO_DEPTH    = 2**ADDR_WIDTH;
    
    // For printer:
    static int WIDTH        = DATA_WIDTH;
    static int DEPTH        = FIFO_DEPTH;

    // TEST params
    static int T_CLK        = SETUP_TIME + 1;       // Taking max+1 of setup and hold. Fifo uses T_DELAY_FF from consts with same value as HOLD_TIME
    static int FREQ         = 10**3 / (T_CLK * 2);  // Mhz (timescale is ns in tb)

    // Sequence params
    static int SEQ_REPEAT   = FIFO_DEPTH * $clog2(DATA_WIDTH);

    `uvm_object_utils_begin(fifo_config)
        `uvm_field_int(WIDTH, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(DEPTH, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(T_CLK, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(FREQ, UVM_DEFAULT | UVM_DEC)
        `uvm_field_int(SEQ_REPEAT, UVM_DEFAULT | UVM_DEC)
    `uvm_object_utils_end
    
    function new(string name = "fifo_config");
        super.new(name);
    endfunction

    virtual function void end_of_elaboration();
        print();
    endfunction
endclass
