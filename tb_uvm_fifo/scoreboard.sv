`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_tlm_analysis_fifo #(transaction) scb_fifo;

    bit [fifo_config::DATA_WIDTH-1:0] mem [$];
    bit [fifo_config::DATA_WIDTH-1:0] tx_dout;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scb_fifo = new("scb_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        transaction ftr;
        int i, msize, exp_full;
        string strvar;
        forever begin
            scb_fifo.get(ftr);
            strvar = $sformatf("push=%0b pull=%0b din=%0h dout=%0h", ftr.push, ftr.pull, ftr.din, ftr.dout);
            uvm_report_info("SCB_FIFO_PORT", strvar);
            if (!ftr.pull && !ftr.push) continue;
            this.count++;
            msize = mem.size();

            // check empty sig
            if (!msize) begin
                assert(ftr.empty)
                    uvm_report_info(get_name(), $sformatf("Pull recieved but FIFO is empty as expected, not pulling. Mem size=%0d", msize));
                else
                    uvm_report_error(get_name(), $sformatf("EMPTY sig not raised. Mem size=%0d", msize));
            end else begin
                assert(!ftr.empty)
                else uvm_report_error(get_name(), $sformatf("EMPTY sig was raised but looks like fifo is not empty. Mem size=%0d", msize));
            end

            // check full sig
            exp_full = fifo_config::FIFO_DEPTH - 1;
            if (msize < exp_full) begin
                assert(!ftr.full)
                else uvm_report_error(get_name(), $sformatf("FULL sig was raised but looks like fifo is not full. Mem size=%0d", msize));
            end else begin
                assert(ftr.full)
                    uvm_report_info(get_name(), $sformatf("Push recieved but FIFO is full as expected, not pushing. Mem size=%0d", msize));
                else
                    uvm_report_error(get_name(), $sformatf("FULL sig not raised. Mem size=%0d", msize));
            end

            // print mem status before any actions
            strvar = "";
            foreach (mem[i]) strvar = { strvar, $sformatf("0x%0h ,", mem[i]) };
            uvm_report_info(get_name(), $sformatf("Current scb mem: %s", strvar));

            // since pull pops mem, then if both are 1 we should push first
            if (ftr.push) begin
                if (mem.size() < exp_full)
                    mem.push_back(ftr.din);
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
    