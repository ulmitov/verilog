`include "uvm_macros.svh"
import uvm_pkg::*;


class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent agt;
    scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("AGT", this);
        scb = scoreboard::type_id::create("SCB", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.mon_port.connect(scb.scb_port);
        uvm_report_info("FIFO_ENV", "Connected ports of MON and SCB successfully", UVM_MEDIUM);
    endfunction
endclass
