class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    transaction req;
    virtual fifo_interface vif;
    uvm_analysis_port #(transaction) mon_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_port = new("MON_PORT", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            wait(!vif.DRIVER_MP.cb_mon.res);
            @(vif.MONITOR_MP.cb_mon);
            req = transaction::type_id::create("req");
            req.pull    = vif.MONITOR_MP.cb_mon.pull;
            req.push    = vif.MONITOR_MP.cb_mon.push;
            req.din     = vif.MONITOR_MP.cb_mon.din;
            req.dout    = vif.MONITOR_MP.cb_mon.dout;
            req.empty   = vif.MONITOR_MP.cb_mon.empty;
            req.full    = vif.MONITOR_MP.cb_mon.full;
            mon_port.write(req);
            if (req.pull || req.push)
                uvm_report_info("MON got item", req.convert2string(), UVM_HIGH);
        end
    endtask
endclass
