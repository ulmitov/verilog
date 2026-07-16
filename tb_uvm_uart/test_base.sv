`include "uvm_macros.svh"
import uvm_pkg::*;
import config_pkg::*;


class test_base #(type SEQ = base_sequence) extends uvm_test;
    `uvm_component_utils(test_base)

    SEQ seq;
    environment env;

    function new(string name, uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
        seq = SEQ::type_id::create();
    endfunction

    task run_phase(uvm_phase ph);
        if (ph == null) uvm_report_error(get_name(), "ph is none");
        ph.raise_objection(this);
        run_sequence();
        ph.drop_objection(this);
        ph.phase_done.set_drain_time(this, TCLK * 4);
    endtask

    task run_sequence;
        this.seq.start(env.agt_apb.sqr);
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (env.agt_apb.drv.count == env.agt_apb.mon.count)
        //if (env.agt_apb.sqr.m_last_rsp_buffer.size() == env.agt_apb.mon.count)
            uvm_report_info(get_name(),
                $sformatf("PASSED: MON got all %0d transactions sent by DRV",
                env.agt_apb.mon.count)
            );
        else
            uvm_report_error(get_name(),
                $sformatf("FAILED: MON got %0d transactions but DRV sent %0d",
                env.agt_apb.mon.count, env.agt_apb.drv.count)
            );
    endfunction
endclass


/*
Regression suite runs all tests via sequence library
*/
class test_regression extends test_base#(seq_lib);
    `uvm_component_utils(test_regression)
    function new(string name = "test_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task run_sequence;
        seq.start(env.agt_apb.sqr);
        seq.print();
    endtask
endclass


/*
Not creating a class per each sequence
as CI runs the regression suite anyway
*/
class test_single extends test_base#(sequence_send_sin_fifo_en);
    `uvm_component_utils(test_single)
    function new(string name = "test_single", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
