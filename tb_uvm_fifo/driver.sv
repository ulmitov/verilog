`include "uvm_macros.svh"
import uvm_pkg::*;


class driver extends uvm_driver#(fifo_transaction);
    `uvm_component_utils(driver)

    virtual fifo_interface vif;
    fifo_transaction ftr;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual fifo_interface)::get(this, "", "vif", vif))
            uvm_report_fatal(get_name(), "build_phase: virtual fifo interface was not set");
    endfunction

    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            seq_item_port.get_next_item(ftr);
            drive_task();
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_task();
        wait(!vif.DRIVER_MP.res);
        @(vif.DRIVER_MP.cb_drv);
        vif.DRIVER_MP.cb_drv.push <= ftr.push;
        vif.DRIVER_MP.cb_drv.pull <= ftr.pull;
        if (ftr.push)
            vif.DRIVER_MP.cb_drv.din <= ftr.din;
        if (ftr.push || ftr.pull) this.count++;
        uvm_report_info("DRV sent item", ftr.convert2string());
    endtask
endclass

