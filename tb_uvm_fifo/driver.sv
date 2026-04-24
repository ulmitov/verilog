`include "uvm_macros.svh"
import uvm_pkg::*;


class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    virtual fifo_interface vif;
    transaction req;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            seq_item_port.get_next_item(req);
            drive_task();
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_task();
        // reset was done in top_tb
        if (vif.DRIVER_MP.res) begin
            wait(!vif.DRIVER_MP.res);
            `ifdef VERILATOR
            @(vif.DRIVER_MP.cb_drv);
            `endif
        end
        @(vif.DRIVER_MP.cb_drv);
        vif.DRIVER_MP.cb_drv.push <= req.push;
        vif.DRIVER_MP.cb_drv.pull <= req.pull;
        vif.DRIVER_MP.cb_drv.din <= req.din;
        if (req.push || req.pull) begin
            this.count++;
            uvm_report_info("DRV sent item", $sformatf("#%0d: %s", this.count, req.convert2string()));
        end
    endtask
endclass

