/*
    Base class for all tests 
*/
class test_base #(type REQ = base_sequence) extends uvm_test;
    `uvm_component_utils(test_base)

    REQ seq;
    environment env;
    fifo_config cfg;
    uvm_factory factory;
    int num_to_full;
    virtual fifo_interface vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task start_sequences;
        /*
            Each test will start sequences here
            then run_phase task will run this task
        */
        reset();
        seq.start(env.agt.sqr);
        seq.print();
    endtask

    virtual task reset;
        vif.res = 1'b1;
        #(fifo_config::TCLK*2) vif.res = 1'b0;
        uvm_report_info(get_name(), "*** RESET DONE ***");
    endtask

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = environment::type_id::create("ENV", this);
        cfg = fifo_config::type_id::create("cfg", this);
        seq = REQ::type_id::create("SEQ");
        // Test parameter passed to sequence via DB:
        uvm_config_db #(int)::set(null, "*", "num_to_full", fifo_config::FIFO_DEPTH * 2);
        if (!uvm_config_db #(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");

        // Register Config class in db. For now not used in this TB:
        //uvm_config_db#(fifo_config)::set(null, "*", "cfg", cfg);
        //if (!uvm_config_db#(fifo_config)::get(this, "", "cfg", cfg))
        //    uvm_report_fatal(get_name(), "fifo_config was not created in test build_phase");
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.phase_done.set_drain_time(this, fifo_config::TCLK * 4);
        phase.raise_objection(this);
        `uvm_info(get_name(), "run_phase: Raised objection", UVM_HIGH)
        start_sequences();
        phase.drop_objection(this);
        `uvm_info(get_name(), "run_phase: Dropped objection", UVM_HIGH)
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


/*
Regression suite runs all tests via sequence library
*/
class test_regression extends test_base#(seq_lib);
    `uvm_component_utils(test_regression)
    function new(string name = "test_regression", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    task start_sequences;
        /*
            Each test will start sequences here
            then run_phase task will run this task
        */
        reset();
        seq.sequence_count = 7;
        seq.print();
        seq.start(env.agt.sqr);
        repeat(2) reset();
        env.scb.flush();
        seq.sequence_count = 2;
        seq.start(env.agt.sqr);
        seq.print();
    endtask
    task configure_phase(uvm_phase phase);
        super.configure_phase(phase);
   endtask
endclass


/*
Not creating a class per each sequence
as CI runs the regression suite anyway
*/
class test_single extends test_base#(sequence_push_pull_00);
    `uvm_component_utils(test_single)
    function new(string name = "test_single", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass
