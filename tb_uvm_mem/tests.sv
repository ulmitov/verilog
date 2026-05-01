`include "uvm_macros.svh"
import uvm_pkg::*;


// Regression suite runs all tests via sequence library
class test_regression extends test_base#(seq_lib);
    `uvm_component_utils(test_regression)
    function new(string name = "test_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task configure_phase(uvm_phase phase);
        super.configure_phase(phase);
        seq.sequence_count = 5;
    endtask
    task start_sequences;
        super.start_sequences();
        // wait one clock for scb ro receive last transaction
        @(posedge vif.clk) reset();
        boot_load();
        seq_read.start(env.agt.sqr);
    endtask
endclass


// Randomized transactions
class test_random extends test_base#(sequence_random);
    `uvm_component_utils(test_random)
    function new(string name = "test_random", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// Consequent write and read back-to-back operations with alternating data bits for all addresses
class test_stuck_bits extends test_base#(sequence_alternating_data);
    `uvm_component_utils(test_stuck_bits)
    function new(string name = "test_stuck_bits", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// Address/Coupling Faults: Writes in opposite direction of addresses with different block sizes
class test_write_opposite extends test_base#(sequence_write_opposite);
    `uvm_component_utils(test_write_opposite)
    function new(string name = "test_write_opposite", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// Write 0x55 and 0xAA to same address then read
class test_stress_pattern extends test_base#(sequence_stress_pattern);
    `uvm_component_utils(test_stress_pattern)
    function new(string name = "test_stress_pattern", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// Invalid addresses
class test_invalid_values extends test_base#(sequence_invalid);
    `uvm_component_utils(test_invalid_values)
    function new(string name = "test_invalid_values", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass


// Init test: Boot load hex file and read whole memmory (TODO: for now runs only for Big Endian case)
class test_boot_load extends test_base#(sequence_read_all);
    `uvm_component_utils(test_boot_load)
    function new(string name = "test_boot_load", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task start_sequences;
        uvm_event ev;
        vif.req = 1'b1;
        reset();
        boot_load();
        seq_read.start(env.agt.sqr);
    endtask
endclass
