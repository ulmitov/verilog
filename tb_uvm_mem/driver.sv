`include "uvm_macros.svh"
import uvm_pkg::*;
`define DMP vif.mp_drv.cb_drv


class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    virtual mem_interface vif;
    transaction req;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mem_interface)::get(this, "", "vif", vif))
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
        if (`DMP.res) begin
            `DMP.wen <= 0;
            `DMP.ren <= 0;
            wait(~`DMP.res);
            `ifdef VERILATOR
            @(`DMP);
            `endif
        end
        @(`DMP);
        `DMP.wen    <= req.wen;
        `DMP.ren    <= req.ren;
        `DMP.blsize <= req.blsize;
        `DMP.addr   <= req.addr;
        `DMP.wr_data <= req.wr_data;
        if (req.wen | req.ren) begin
            count++;
            uvm_report_info("DRV_SEQ", $sformatf("[#%0d] %s", count, req.convert2string()));
        end
    endtask
endclass

