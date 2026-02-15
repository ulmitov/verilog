`include "uvm_macros.svh"
import uvm_pkg::*;


class agent extends uvm_agent;
    `uvm_component_utils(agent)

    sequencer sqr;
    driver drv;
    monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("DRV", this);
        mon = monitor::type_id::create("MON", this);
        sqr = sequencer::type_id::create("SQR", this);
    endfunction

    function void connect_phase(uvm_phase ph);
        super.connect_phase(ph);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
