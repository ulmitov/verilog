`include "uvm_macros.svh"
import uvm_pkg::*;


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) mon_port;
    virtual mem_interface vif;
    transaction req;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_port = new("mon_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mem_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        `define MIF vif.mp_mon.cb_mon
        super.run_phase(phase);
        forever begin
            req = transaction::type_id::create("req");
            @(`MIF);
            req.wen = `MIF.wen;
            req.ren = `MIF.ren;
            req.addr = `MIF.addr;
            req.wr_data = `MIF.wr_data;
            req.rd_data = `MIF.rd_data;
            req.blsize = `MIF.blsize;
            uvm_report_info("MON_SEQ", req.convert2string(), UVM_HIGH);
            mon_port.write(req);
        end
    endtask
endclass
