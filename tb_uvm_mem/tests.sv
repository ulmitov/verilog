`include "uvm_macros.svh"
import uvm_pkg::*;


/*
Regression suite runs all tests via sequence library
*/
class test_regression extends test_base#(seq_lib);
    `uvm_component_utils(test_regression)
    function new(string name = "test_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task configure_phase(uvm_phase phase);
        super.configure_phase(phase);
        `uvm_info("CFG_PHASE", "Sequences library:", UVM_MEDIUM)
        seq.sequence_count = 6;
        // todo randomize num of transaction for each seq
   endtask
endclass



/*
Randomized transactions
*/
class test_random extends test_base#(sequence_random);
    `uvm_component_utils(test_random)
    function new(string name = "test_random", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

/*
Fill with 0x00 then read
*/
class test_fill_00 extends test_base#(sequence_fill_00);
    `uvm_component_utils(test_fill_00)
    function new(string name = "test_fill_00", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Fill with 0xFF then read
*/
class test_fill_FF extends test_base#(sequence_fill_FF);
    `uvm_component_utils(test_fill_FF)
    function new(string name = "test_fill_FF", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Write data with maximum block size then read
*/
class test_wr_rd extends test_base#(sequence_wr_rd);
    `uvm_component_utils(test_wr_rd)
    function new(string name = "test_wr_rd", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
