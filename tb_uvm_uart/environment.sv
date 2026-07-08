class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent_apb agt_apb;
    agent_pin agt_pin;
    scoreboard scb;
    top_config cfg;
    ral_env ral;

    function new(string name = "ENV", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        agt_apb = agent_apb::type_id::create("AGT_APB", this);
        agt_pin = agent_pin::type_id::create("AGT_PIN", this);
        cfg = top_config::type_id::create();
        scb = scoreboard::type_id::create("SCB", this);
        ral = ral_env::type_id::create("RAL", this);
        uvm_config_db#(ral_env)::set(null, "*", "ral", ral);
        uvm_config_db#(top_config)::set(null, "*", "cfg", cfg);
    endfunction

    function void connect_phase(uvm_phase ph);
        super.connect_phase(ph);
        agt_apb.mon.mon_port.connect(scb.scb_fifo.analysis_export);
        agt_pin.mon.mon_port.connect(scb.pin_fifo.analysis_export);

        // RAL model:
        agt_apb.mon.mon_port.connect(ral.predictor.bus_in);
        ral.csr.apb_map.set_sequencer(agt_apb.sqr, ral.adapter);
        ral.csr.dlab_map.set_sequencer(agt_apb.sqr, ral.adapter);
    endfunction
endclass
