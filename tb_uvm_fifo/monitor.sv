`include "uvm_macros.svh"
import uvm_pkg::*;


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    uvm_analysis_port #(transaction) mon_port;
    virtual fifo_interface vif;
    transaction ftr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_port = new("mon_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual fifo interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        ftr = transaction::type_id::create("ftr");

        forever begin
            @(vif.MONITOR_MP.cb_mon);
            ftr.pull = vif.MONITOR_MP.cb_mon.pull;
            ftr.push = vif.MONITOR_MP.cb_mon.push;
            if (ftr.pull || ftr.push) begin
                ftr.din = vif.MONITOR_MP.cb_mon.din;
                ftr.dout = vif.MONITOR_MP.cb_mon.dout;
                ftr.empty = vif.MONITOR_MP.cb_mon.empty;
                ftr.full = vif.MONITOR_MP.cb_mon.full;
                uvm_report_info("MON got item", ftr.convert2string(), UVM_HIGH);
                //`uvm_info( "MON", ftr.sprint( uvm_default_line_printer ), UVM_NONE )
                mon_port.write(ftr);
            end
        end
    endtask
endclass
