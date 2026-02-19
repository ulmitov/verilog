/*
Main test which runs all tests
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class test_full extends uvm_test;
    `uvm_component_utils(test_full)

    environment env;
    fifo_sequence seq_wr_rd_rand;
    fifo_sequence_wr_rd seq_wr_rd_single;
    fifo_sequence_wr_rd_completely seq_wr_rd_multiple;
    fifo_sequence_manual seq_manual;
    fifo_config cfg;
    uvm_factory factory;
    int seq_single;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
        // Just an exmaple of Config registered in db, no real use case in TB
        cfg = fifo_config::type_id::create("cfg",this);
        uvm_config_db #(fifo_config)::set(null, "*", "cfg", cfg);
        // get cfg from db:
        //if (!uvm_config_db#(fifo_config)::get(this, "", "cfg", cfg))
        //    uvm_report_fatal(get_name(), "fifo_config was not created in test build_phase");
        seq_single = 2 * fifo_config::FIFO_DEPTH;
        uvm_config_db #(int)::set(null, "*", "seq_single", seq_single);
    endfunction

    virtual function void end_of_elaboration();
        print();
        uvm_report_info(get_name(), "::: CONFIG :::");
        cfg.print();
        uvm_report_info(get_name(), "::: FACTORY :::");
        factory = uvm_factory::get();
        factory.print();
    endfunction

    virtual task run_phase(uvm_phase phase);
        seq_manual = fifo_sequence_manual::type_id::create("seq_manual");
        seq_wr_rd_rand = fifo_sequence::type_id::create("seq_wr_rd_rand");
        seq_wr_rd_single = fifo_sequence_wr_rd::type_id::create("seq_wr_rd_single");
        seq_wr_rd_multiple = fifo_sequence_wr_rd_completely::type_id::create("seq_wr_rd_multiple");
        phase.raise_objection(this);
        seq_manual.start(env.agt.sqr);
        seq_wr_rd_single.start(env.agt.sqr);
        seq_wr_rd_multiple.start(env.agt.sqr);
        seq_wr_rd_rand.start(env.agt.sqr);
        phase.drop_objection(this);
        phase.phase_done.set_drain_time(this, fifo_config::T_CLK * 4);
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        assert(env.agt.drv.count == env.scb.count)
            uvm_report_info(get_name(), $sformatf("PASSED: SCB got all %0d transactions sent by DRV", env.scb.count));
        else
            uvm_report_error(get_name(), $sformatf("FAILED: SCB got %0d transactions but DRV sent %0d", env.scb.count, env.agt.drv.count));
    endfunction
endclass
