`define MCB vif_apb.mp_mon.cb_mon


class monitor_apb extends uvm_monitor;
    `uvm_component_utils(monitor_apb)

    transaction req;
    virtual interface_apb vif_apb;
    uvm_analysis_port #(transaction) mon_port;
    longint count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        mon_port = new("MNP", this);
        if (!uvm_config_db#(virtual interface_apb)::get(this, "", "vif_apb", vif_apb))
            uvm_report_fatal(get_name(), "vif_apb is not in db");
    endfunction

    task run_phase(uvm_phase ph);
        super.run_phase(ph);
        forever begin
            monitor();
        end
    endtask

    task monitor;
        @(`MCB);
        if (`MCB.presetn === 1 & `MCB.pready !== 1) return;
        req = transaction::type_id::create();
        req.psel    = `MCB.psel;
        req.paddr   = `MCB.paddr;
        req.pwrite  = `MCB.pwrite;
        req.pwdata  = `MCB.pwdata;
        req.penable = `MCB.penable;
        req.pslverr = `MCB.pslverr;
        req.presetn = `MCB.presetn;
        req.pready  = `MCB.pready;
        req.prdata  = `MCB.prdata;
        uvm_report_info(get_name(), req.convert2string(), UVM_FULL);
        mon_port.write(req);
        if (req.presetn == 1) count++;
    endtask
endclass
