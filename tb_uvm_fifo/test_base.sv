/*
    Base class for all tests 
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class test_base #(type REQ = base_sequence) extends uvm_test;
    `uvm_component_utils(test_base)

    environment env;
    fifo_config cfg;
    uvm_factory factory;
    REQ seq;

    int num_to_full;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task start_sequences;
        /*
            Each test will start sequences here
            then run_phase task will run this task
        */
        seq.start(env.agt.sqr);
        seq.print();
    endtask

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
        cfg = fifo_config::type_id::create("cfg", this);
        seq = REQ::type_id::create("SEQ");
        // Test parameter passed to sequence via DB:
        uvm_config_db #(int)::set(null, "*", "num_to_full", fifo_config::FIFO_DEPTH * 2);

        // Register Config class in db. For now not used in this TB:
        //uvm_config_db#(fifo_config)::set(null, "*", "cfg", cfg);
        //if (!uvm_config_db#(fifo_config)::get(this, "", "cfg", cfg))
        //    uvm_report_fatal(get_name(), "fifo_config was not created in test build_phase");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_name(), "Raised objection", UVM_HIGH)
        start_sequences();
        phase.drop_objection(this);
        `uvm_info(get_name(), "Dropped objection", UVM_HIGH)
        phase.phase_done.set_drain_time(this, fifo_config::T_CLK * 4);
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (env.agt.drv.count == env.scb.count)
            uvm_report_info(get_name(),
                $sformatf("PASSED: SCB got all %0d transactions sent by DRV", env.scb.count));
        else
            uvm_report_error(get_name(),
                $sformatf("FAILED: SCB got %0d transactions but DRV sent %0d", env.scb.count, env.agt.drv.count));
    endfunction

    virtual function void end_of_elaboration();
        print();
        uvm_report_info(get_name(), "::: CONFIG :::");
        cfg.print();
        uvm_report_info(get_name(), "::: FACTORY :::");
        factory = uvm_factory::get();
        factory.print();
    endfunction
endclass
