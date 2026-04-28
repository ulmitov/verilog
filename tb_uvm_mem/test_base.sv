/*
    Base class for all tests 
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class test_base #(type REQ = base_sequence) extends uvm_test;
    `uvm_component_utils(test_base)

    environment env;
    mem_config cfg;
    uvm_factory factory;
    virtual mem_interface vif;
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
        vif.res = 1'b1;
        #(mem_config::T_CLK*2) vif.res = 1'b0;
        `uvm_info(get_name(), "*** RESET DONE ***", UVM_MEDIUM)
        seq.start(env.agt.sqr);
        seq.print();
    endtask

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
        cfg = mem_config::type_id::create("CFG", this);
        seq = REQ::type_id::create("SEQ");
        if (!uvm_config_db #(virtual mem_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");
        // Test parameter passed to sequence via DB:
        uvm_config_db #(int)::set(null, "*", "num_to_full", mem_config::DEPTH);

        // Register Config class in db. For now not used in this TB:
        //uvm_config_db#(mem_config)::set(null, "*", "CFG", cfg);
        //if (!uvm_config_db#(mem_config)::get(this, "", "CFG", cfg))
        //    uvm_report_fatal(get_name(), "mem_config was not created in test build_phase");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.phase_done.set_drain_time(this, mem_config::T_CLK * 4);
        phase.raise_objection(this);
        `uvm_info(get_name(), "Raised objection", UVM_HIGH)
        start_sequences();
        phase.drop_objection(this);
        `uvm_info(get_name(), "Dropped objection", UVM_HIGH)
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
        uvm_report_info(get_name(), $sformatf("DATA_WIDTH=%d", mem_config::DATA_WIDTH));
        uvm_report_info(get_name(), "::: FACTORY :::");
        factory = uvm_factory::get();
        factory.print();
    endfunction
endclass
