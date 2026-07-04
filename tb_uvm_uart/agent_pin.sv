class agent_pin extends uvm_agent;
    `uvm_component_utils(agent_pin)

    driver_pin drv;
    monitor_pin mon;
    sequencer_pins sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        drv = driver_pin::type_id::create("DRV_PIN", this);
        mon = monitor_pin::type_id::create("MON_PIN", this);
        sqr = sequencer_pins::type_id::create("SQR_PIN", this);
        uvm_config_db#(sequencer_pins)::set(null, "*", "sqr_pin", sqr);
    endfunction

    function void connect_phase(uvm_phase ph);
        super.connect_phase(ph);
        drv.seq_item_port.connect(sqr.seq_item_export);
        drv.rsp_port.connect(sqr.rsp_export);
    endfunction
endclass
