`include "uvm_macros.svh"
import uvm_pkg::*;


class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    virtual fifo_interface vif;
    fifo_transaction ftr;
    int count;

    uvm_analysis_port #(fifo_transaction) mon_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        mon_port = new("mon_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal("MON", {"build_phase: virtual fifo interface was not set for ", get_name()});
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);

        ftr = fifo_transaction#()::type_id::create("ftr");

        forever begin
            @(posedge vif.MONITOR_MP.clk);
            ftr.pull = vif.MONITOR_MP.cb_mon.pull;
            ftr.push = vif.MONITOR_MP.cb_mon.push;
            if (ftr.pull || ftr.push) begin
                ftr.din = vif.MONITOR_MP.cb_mon.din;
                ftr.dout = vif.MONITOR_MP.cb_mon.dout;
                ftr.empty = vif.MONITOR_MP.cb_mon.empty;
                ftr.full = vif.MONITOR_MP.cb_mon.full;
                ftr.print("MON got item");
                mon_port.write(ftr);
            end
        end
    endtask
endclass
