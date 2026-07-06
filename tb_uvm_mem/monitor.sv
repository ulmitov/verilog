`define MIF vif.mp_mon.cb_mon


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) mon_port;
    virtual mem_interface vif;
    transaction req;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_port = new("MON_PORT", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mem_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            @(`MIF);
            if (`MIF.res) continue;
            if (!`MIF.req) continue;
            req = transaction::type_id::create("req");
            req.wen     = `MIF.wen;
            req.ren     = `MIF.ren;
            req.req     = `MIF.req;
            req.addr    = `MIF.addr;
            req.blsize  = `MIF.blsize;
            req.wr_data = `MIF.wr_data;
            req.rd_data = `MIF.rd_data;
            uvm_report_info("MON_SEQ", req.convert2string(), UVM_HIGH);
            mon_port.write(req);
        end
    endtask
endclass
