`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard #(parameter WORD_WIDTH = 8, parameter ADDR_WIDTH = 3) extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(fifo_transaction, scoreboard) scb_port;

    fifo_transaction Q [$];

    bit [WORD_WIDTH-1:0] mem [$];
    bit [WORD_WIDTH-1:0] tx_dout;
    int count = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        scb_port = new("scb_port", this);
    endfunction

    function write(fifo_transaction tr);
        Q.push_back(tr);
        tr.print("SCB got item");
    endfunction

    task run_phase(uvm_phase ph);
        fifo_transaction tr;
        int memsize;
        forever begin
            wait (Q.size() > 0);
            tr = Q.pop_front();
            uvm_report_info(get_name(), $sformatf("Q popped packet push=%0b pull=%0b din=%0h:", tr.push, tr.pull, tr.din), UVM_MEDIUM);
            if (!tr.pull && !tr.push) continue;
            this.count++;
            memsize = mem.size();

            if (!memsize) begin
                assert(tr.empty)
                    uvm_report_info(get_name(), $sformatf("Pull request recieved but FIFO is empty, nothing to do, waiting for next request"), UVM_MEDIUM);
                else
                    uvm_report_error(get_name(), $sformatf("EMPTY sig not raised"));
            end else if (memsize == 2**ADDR_WIDTH) begin
                assert(tr.full)
                    uvm_report_info(get_name(), $sformatf("Push request recieved but FIFO is full, nothing to do, waiting for next request"), UVM_MEDIUM);
                else
                    uvm_report_error(get_name(), $sformatf("FULL sig not raised"));
            end


            if (tr.pull && memsize) begin
                tx_dout = mem.pop_front();

                assert(tx_dout == tr.dout) begin
                    uvm_report_info(get_name(), $sformatf("-------------------"), UVM_MEDIUM);
                    uvm_report_info(get_name(), $sformatf("--- EXPECTED MATCH"), UVM_MEDIUM);
                    uvm_report_info(get_name(), $sformatf("Exp=%0h, Receieved %0h", tx_dout, tr.dout), UVM_MEDIUM);
                    uvm_report_info(get_name(), $sformatf("-------------------"), UVM_MEDIUM);
                end else begin
                    uvm_report_info(get_name(), $sformatf("-------------------"), UVM_MEDIUM);
                    uvm_report_info(get_name(), $sformatf("--- FAILED MATCH"), UVM_MEDIUM);
                    uvm_report_error(get_name(), $sformatf("Exp=%0h, Receieved %0h", tx_dout, tr.dout));
                    uvm_report_info(get_name(), $sformatf("-------------------"), UVM_MEDIUM);
                end
            end
            if (tr.push && memsize < 2**ADDR_WIDTH) mem.push_back(tr.din);
            uvm_report_info(get_name(), $sformatf("Current scb mem:"), UVM_MEDIUM);
            uvm_report_info(get_name(), $sformatf("%p", mem), UVM_MEDIUM);
        end
    endtask
endclass
    