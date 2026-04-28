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
    task start_sequences;
        /*
            Each test will start sequences here
            then run_phase task will run this task
        */
        reset();
        seq.sequence_count = 6;
        seq.print();
        seq.start(env.agt.sqr);
        repeat(2) reset();
        env.scb.flush();
        seq.sequence_count = 2;
        seq.start(env.agt.sqr);
        seq.print();
    endtask
    task configure_phase(uvm_phase phase);
        super.configure_phase(phase);
   endtask
endclass


/*
Push 0x00 until full, pull until empty
*/
class test_push_00 extends test_base#(sequence_push_pull_00);
    `uvm_component_utils(test_push_00)
    function new(string name = "test_push_00", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Push 0xFF until full, pull until empty
*/
class test_push_ff extends test_base#(sequence_push_pull_ff);
    `uvm_component_utils(test_push_ff)
    function new(string name = "test_push_ff", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Consecutive single push then pull pairs after empty was set having data_in with only 1 bit set (repeat for all data bits)
*/
class test_push_pull_while_empty extends test_base#(sequence_consecutives_while_empty);
    `uvm_component_utils(test_push_pull_while_empty)
    function new(string name = "test_push_pull_while_empty", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Consecutive single push then pull pairs after empty was set having data_in with only 1 bit set (repeat for all data bits)
*/
class test_push_pull_while_full extends test_base#(sequence_consecutives_while_full);
    `uvm_component_utils(test_push_pull_while_full)
    function new(string name = "test_push_pull_while_full", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Push and pull in parallel while full,  data_in alternates with 0x00 and 0xFF
Push and pull in parallel while empty, data_in alternates with 0x00 and 0xFF
*/
class test_parallel extends test_base#(sequence_parallel);
    `uvm_component_utils(test_parallel)
    function new(string name = "test_parallel", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


/*
Fully randomized transactions
*/
class test_random extends test_base#(sequence_rand);
    `uvm_component_utils(test_random)
    function new(string name = "test_random", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
