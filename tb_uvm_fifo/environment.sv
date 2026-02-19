`include "uvm_macros.svh"
import uvm_pkg::*;


class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent agt;
    coverage cvg;
    scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("AGT", this);
        cvg = coverage::type_id::create("CVG", this);
        scb = scoreboard::type_id::create("SCB", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.mon_port.connect(scb.scb_fifo.analysis_export); // Broadcast monitor to scoreboard fifo
        agt.mon.mon_port.connect(cvg.analysis_export);          // Broadcast monitor to coverage
        uvm_report_info("ENV", "Connected ports of MON and SCB successfully", UVM_MEDIUM);
    endfunction
endclass
