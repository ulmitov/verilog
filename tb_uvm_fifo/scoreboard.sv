`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_tlm_analysis_fifo #(transaction) scb_fifo;

    transaction ftr;
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
        int i, msize, exp_full;
        string strvar;
        forever begin
            scb_fifo.get(ftr);
            uvm_report_info("SCB_FIFO_PORT", ftr.convert2string());
            if (!ftr.pull && !ftr.push) continue;
            this.count++;
            msize = mem.size();

            // check empty sig
            if (!msize) begin
                assert(ftr.empty) else
                    uvm_report_error(get_name(), $sformatf("EMPTY sig not raised. Mem size=%0d", msize));
            end else begin
                assert(!ftr.empty) else
                    uvm_report_error(get_name(),
                        $sformatf("EMPTY is set but fifo is not empty. Mem size=%0d", msize));
            end

            // check full sig
            exp_full = fifo_config::FIFO_DEPTH;
            if (msize < exp_full) begin
                assert(!ftr.full) else
                    uvm_report_error(get_name(),
                        $sformatf("FULL is set but fifo is not full. Mem size=%0d", msize));
            end else begin
                assert(ftr.full) else
                    uvm_report_error(get_name(), $sformatf("FULL sig not raised. Mem size=%0d", msize));
            end

            // print mem status
            strvar = "";
            foreach (mem[i]) strvar = { strvar, $sformatf("0x%0h ,", mem[i]) };
            uvm_report_info(get_name(), $sformatf("Current scb mem: [%s]", strvar), UVM_HIGH);

            // since pull pops mem, then if both are 1 we should push first
            if (ftr.push) begin
                if (mem.size() < exp_full)
                    mem.push_back(ftr.din);
            end

            // check pull dout
            if (ftr.pull && msize) begin
                tx_dout = mem.pop_front();
                assert(tx_dout == ftr.dout)
                    this.passed(tx_dout, ftr.dout);
                else
                    this.failed(tx_dout, ftr.dout);
            end
        end
    endtask

    function void passed(int exp, int rec);
        uvm_report_info(get_name(),
            $sformatf("--- PASSED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
    endfunction
    function void failed(int exp, int rec);
        uvm_report_info(get_name(), $sformatf("-------------------"));
        uvm_report_error(get_name(),
            $sformatf("--- FAILED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
        uvm_report_info(get_name(), $sformatf("-------------------"));
    endfunction
endclass
