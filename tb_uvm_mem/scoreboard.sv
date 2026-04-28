`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    parameter DWIDTH = mem_config::DATA_WIDTH;

    uvm_tlm_analysis_fifo #(transaction) scb_fifo;
    transaction req;

    bit [DWIDTH-1:0] mem_ref [0:mem_config::DEPTH];
    bit [DWIDTH-1:0] tx_dout;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scb_fifo = new("scb_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        int i, blen;
        int x, y;
        bit [DWIDTH-1:0] prev_read;
        int rd_done = 0;
        forever begin
            scb_fifo.get(req);
            uvm_report_info("SCB_SEQ", req.convert2string);
            /*
            if (req.res) begin: init_mem_ref
                uvm_report_info("SCB_SEQ", "RESET performed");
                for (i = 0; i < mem_config::DEPTH; i = i + 1)
                    mem_ref[i] = 0;
            end
            */
            if (!req.wen && !req.ren) continue;
            this.count++;

            case (req.blsize)
                OP_DMEM_HALF: blen = DWIDTH > 8 ? 2 : 1;
                OP_DMEM_TRPL: blen = DWIDTH > 16 ? 3 : 1;
                OP_DMEM_WORD: blen = DWIDTH > 24 ? 4 : 1;
                OP_DMEM_DUBL: blen = DWIDTH > 32 ? 8 : 1;
                OP_DMEM_QUAD: blen = DWIDTH > 64 ? 16 : 1;
                default: blen = 1;
            endcase

            if (req.wen) begin
                for (i = 0; i < blen; i = i + 1) begin
                    x = req.addr + i;
                    y = ((i+1)*8-1);
                    mem_ref[x] = req.wr_data[y-:8];
                end
                // rd_data remained last read value
                if (rd_done) begin
                    assert(prev_read == req.rd_data)
                        this.passed(prev_read, req.rd_data);
                    else
                        this.failed(prev_read, req.rd_data);
                end
            end

            if (req.ren) begin
                tx_dout = 0;
                for (i = 0; i < blen; i = i + 1) begin
                    x = req.addr + i;
                    if (mem_config::ENDIANESS)
                        y = ((blen-i)*8-1);
                    else
                        y = ((i+1)*8-1);
                    tx_dout[y-:8] = mem_ref[x];
                end
                rd_done = 1;
                prev_read = req.rd_data;

                assert(tx_dout == req.rd_data)
                    this.passed(tx_dout, req.rd_data);
                else
                    this.failed(tx_dout, req.rd_data);
            end
        end
    endtask

    function void passed(bit [DWIDTH-1:0] exp, bit [DWIDTH-1:0] rec);
        uvm_report_info(get_name(),
            $sformatf("--- PASSED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
    endfunction
    function void failed(bit [DWIDTH-1:0] exp, bit [DWIDTH-1:0] rec);
        int i;
        string strvar;
        uvm_report_info(get_name(), $sformatf("-------------------"));
        uvm_report_error(get_name(),
            $sformatf("--- FAILED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
        // print mem status
        strvar = "";
        foreach (mem_ref[i]) strvar = { strvar, $sformatf("0x%0h ,", mem_ref[i]) };
        uvm_report_info(get_name(), $sformatf("Current mem: [%s]", strvar), UVM_HIGH);
        uvm_report_info(get_name(), $sformatf("-------------------"));
    endfunction
endclass
    