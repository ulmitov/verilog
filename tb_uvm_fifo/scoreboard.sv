`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(fifo_transaction, scoreboard) scb_port;

    fifo_transaction Q [$];

    bit [fifo_config::DATA_WIDTH-1:0] mem [$];
    bit [fifo_config::DATA_WIDTH-1:0] tx_dout;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase ph);
        super.build_phase(ph);
        scb_port = new("scb_port", this);
    endfunction

    function write(fifo_transaction ftr);
        Q.push_back(ftr);
        uvm_report_info("SCB got item", ftr.convert2string());
    endfunction

    task run_phase(uvm_phase ph);
        fifo_transaction ftr;
        int msize;
        int i;
        string strvar;
        forever begin
            wait (Q.size() > 0);
            ftr = Q.pop_front();
            uvm_report_info(get_name(), $sformatf("Q popped packet push=%0b pull=%0b din=%0h:", ftr.push, ftr.pull, ftr.din), UVM_MEDIUM);
            if (!ftr.pull && !ftr.push) continue;
            this.count++;
            msize = mem.size();

            // check empty sig
            if (!msize) begin
                assert(ftr.empty)
                    uvm_report_info(get_name(), $sformatf("Pull request recieved but FIFO is empty as expected, not pulling, waiting for next request"), UVM_MEDIUM);
                else
                    uvm_report_error(get_name(), $sformatf("EMPTY sig not raised"));
            end else begin
                assert(!ftr.empty)
                else uvm_report_error(get_name(), $sformatf("EMPTY sig was raised but looks like fifo is not empty"));
            end

            // check full sig
            if (msize < fifo_config::FIFO_DEPTH) begin
                assert(!ftr.full)
                else uvm_report_error(get_name(), $sformatf("FULL sig was raised but looks like fifo is not full"));
            end else begin
                assert(ftr.full)
                    uvm_report_info(get_name(), $sformatf("Push request recieved but FIFO is full as expected, not pushing, waiting for next request"), UVM_MEDIUM);
                else
                    uvm_report_error(get_name(), $sformatf("FULL sig not raised"));
            end

            // print mem status before any actions
            strvar = "";
            foreach (mem[i]) strvar = { strvar, $sformatf("0x%0h ,", mem[i]) };
            uvm_report_info(get_name(), $sformatf("Current scb mem: %s", strvar));

            // since pull pops mem, then if both are 1 we should push first
            if (ftr.push) begin
                if (mem.size() < fifo_config::FIFO_DEPTH) mem.push_back(ftr.din);
            end

            // check pull operation
            if (ftr.pull && msize) begin
                tx_dout = mem.pop_front();
                assert(tx_dout == ftr.dout)
                    this.passed(tx_dout, ftr.dout);
                else
                    this.failed(tx_dout, ftr.dout);
            end
        end
    endtask

    function passed(int exp, int rec);
        this.log(exp, rec, "PASSED");
    endfunction

    function failed(int exp, int rec);
        this.log(exp, rec, "FAILED", UVM_ERROR);
    endfunction

    function void log(int exp, int rec, string status, uvm_severity sev = UVM_INFO);
        uvm_report_info(get_name(), $sformatf("-------------------"));
        uvm_report_info(get_name(), $sformatf("--- %s MATCH", status));
        uvm_report(sev, get_name(), $sformatf("Exp=0x%0h | Rec=0x%0h", exp, rec));
        uvm_report_info(get_name(), $sformatf("-------------------"));
    endfunction
endclass
    