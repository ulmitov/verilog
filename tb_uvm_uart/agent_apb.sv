class agent_apb extends uvm_agent;
    `uvm_component_utils(agent_apb)

    driver_apb drv;
    monitor_apb mon;
    sequencer_apb sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        drv = driver_apb::type_id::create("DRV_APB", this);
        mon = monitor_apb::type_id::create("MON_APB", this);
        sqr = sequencer_apb::type_id::create("SQR_APB", this);
    endfunction

    function void connect_phase(uvm_phase ph);
        super.connect_phase(ph);
        drv.seq_item_port.connect(sqr.seq_item_export);
        drv.rsp_port.connect(sqr.rsp_export);
    endfunction
endclass
