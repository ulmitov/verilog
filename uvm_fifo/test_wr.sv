/*
Do write+read one after another
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class test_wr extends fifo_test;
    `uvm_component_utils(test_wr)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        seq_wr_rd_single = fifo_sequence_wr_rd::type_id::create("SEQ");
        phase.raise_objection(this);
        seq_wr_rd_single.start(env.agt.sqr);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, 20);
    endtask
endclass
