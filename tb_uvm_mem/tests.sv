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


/*
Not creating a class per each sequence
as CI runs the regression suite anyway
*/
class test_single extends test_base#(sequence_random);
    `uvm_component_utils(test_single)
    function new(string name = "test_single", uvm_component parent = null);
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
