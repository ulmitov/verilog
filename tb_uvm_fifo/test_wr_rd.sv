/*
Make many writes, then many reads
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class test_wr_rd extends test_full;
    `uvm_component_utils(test_wr_rd)

    function new(string name = "test_wr_rd", uvm_component parent = null);
        super.new(name, parent);
        seq_single = 2 * fifo_config::FIFO_DEPTH;
        uvm_config_db #(int)::set(null, "*", "seq_single", seq_single);
    endfunction

    task run_phase(uvm_phase phase);
        seq_wr_rd_multiple = fifo_sequence_wr_rd_completely::type_id::create("SEQ");
        phase.raise_objection(this);
        seq_wr_rd_multiple.start(env.agt.sqr);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, 20);
    endtask
endclass
