`include "uvm_macros.svh"
import uvm_pkg::*;


class fifo_test extends uvm_test;
    `uvm_component_utils(fifo_test)

    environment env;
    fifo_sequence seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
    endfunction

    virtual function void end_of_elaboration();
        print();
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq = fifo_sequence::type_id::create("SEQ");
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, 30);
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        assert(env.agt.drv.count == env.scb.count)
            uvm_report_info(get_name(), $sformatf("SCB got all %0d transactions", env.scb.count), UVM_MEDIUM);
        else
            uvm_report_error(get_name(), $sformatf("SCB got %0d transactions but DRV sent %0d", env.scb.count, env.agt.drv.count));
    endfunction
endclass
