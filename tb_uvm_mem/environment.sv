`include "uvm_macros.svh"
import uvm_pkg::*;


class environment extends uvm_env;
    `uvm_component_utils(environment)

    agent agt;
    //agent agt_wr;
    //agent agt_rd;
    `ifndef VERILATOR
    coverage cvg;
    `endif
    scoreboard scb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("AGT", this);
        //agt_rd = agent::type_id::create("ARD", this);
        //agt_wr = agent::type_id::create("AWR", this);
        `ifndef VERILATOR
        cvg = coverage::type_id::create("CVG", this);
        `endif
        scb = scoreboard::type_id::create("SCB", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.mon_port.connect(scb.scb_fifo.analysis_export); // Broadcast monitor to scoreboard fifo
        `ifndef VERILATOR
        agt.mon.mon_port.connect(cvg.analysis_export);          // Broadcast monitor to coverage
        `endif
        //agt_rd.mon.mon_port.connect(scb.scb_fifo_rd.analysis_export); // Broadcast monitor to scoreboard fifo
        //agt_rd.mon.mon_port.connect(cvg.analysis_export);          // Broadcast monitor to coverage
        uvm_report_info("ENV", "Connected ports of MON and SCB successfully", UVM_MEDIUM);
    endfunction
endclass
