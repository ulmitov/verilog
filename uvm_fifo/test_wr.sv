`include "uvm_macros.svh"
import uvm_pkg::*;


class test_wr extends fifo_test;
    `uvm_component_utils(test_wr)

    fifo_sequence_wr seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        seq = fifo_sequence_wr::type_id::create("SEQ");
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, 30);
    endtask
endclass
