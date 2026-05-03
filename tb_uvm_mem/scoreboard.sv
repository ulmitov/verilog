`include "uvm_macros.svh"
import uvm_pkg::*;


class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)
    parameter int WIDTH = mem_config::DATA_WIDTH;
    parameter int DEPTH = mem_config::DEPTH;

    uvm_tlm_analysis_fifo #(transaction) scb_fifo;
    transaction req;

    bit [WIDTH-1:0] mem_ref [0:DEPTH];
    bit [WIDTH-1:0] tx_dout;
    int count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        scb_fifo = new("scb_fifo", this);
    endfunction

    function void flush();
        mem_ref = '{default:0};
    endfunction

    task boot_load(string memcode_path);
        uvm_report_info(get_name(), $sformatf("--- LOADING IMAGE %s ---", memcode_path));
        $readmemh(memcode_path, mem_ref);
    endtask

    virtual task run_phase(uvm_phase phase);
        forever begin
            scb_fifo.get(req);
            /*
            if (req.res) begin: init_mem_ref
                uvm_report_info("SCB_SEQ", "RESET performed");
                for (i = 0; i < DEPTH; i = i + 1)
                    mem_ref[i] = 0;
            end
            */
            if (!req.wen && !req.ren) continue;
            count++;
            uvm_report_info("SCB_SEQ", $sformatf("[#%0d] %s", count, req.convert2string()));
            check_req();
        end
    endtask

    function void check_req;
        bit [WIDTH-1:0] prev_read;
        int i, x, y, blen;
        int rd_done = 0;
        case (req.blsize)
            OP_DMEM_BYTE: blen = 1;
            OP_DMEM_HALF: blen = WIDTH > 8 ? 2 : mem_config::BUS_BLOCKS;
            OP_DMEM_TRPL: blen = WIDTH > 16 ? 3 : mem_config::BUS_BLOCKS;
            OP_DMEM_WORD: blen = WIDTH > 24 ? 4 : mem_config::BUS_BLOCKS;
            OP_DMEM_DUBL: blen = WIDTH > 32 ? 8 : mem_config::BUS_BLOCKS;
            OP_DMEM_QUAD: blen = WIDTH > 64 ? 16 : mem_config::BUS_BLOCKS;
            default: blen = mem_config::BUS_BLOCKS;
        endcase

        if (req.addr < DEPTH && req.addr + blen >= DEPTH)
            blen = DEPTH - req.addr;

        if (req.wen && req.addr < DEPTH) begin
            for (i = 0; i < blen; i = i + 1) begin
                x = req.addr + i;
                y = ((i+1)*8-1);
                mem_ref[x] = req.wr_data[y-:8];
            end
            // rd_data should remain previous value
            if (rd_done) begin
                assert(prev_read == req.rd_data)
                    this.passed(prev_read, req.rd_data);
                else
                    this.failed(prev_read, req.rd_data);
            end
        end

        if (req.ren) begin
            tx_dout = 0;
            if (req.addr < DEPTH) begin
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
            end

            assert(tx_dout == req.rd_data)
                this.passed(tx_dout, req.rd_data);
            else
                this.failed(tx_dout, req.rd_data);
        end
    endfunction

    function void passed(bit [WIDTH-1:0] exp, bit [WIDTH-1:0] rec);
        //dump_mem();
        uvm_report_info(get_name(),
            $sformatf("--- PASSED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
    endfunction

    function void failed(bit [WIDTH-1:0] exp, bit [WIDTH-1:0] rec);
        uvm_report_info(get_name(), $sformatf("-------------------"));
        uvm_report_error(get_name(),
            $sformatf("--- FAILED MATCH: Exp=0x%0h | Rec=0x%0h", exp, rec));
        dump_mem();
    endfunction

    function void dump_mem;
        uvm_event ev;
        string strvar;
        int i;
        strvar = "";
        foreach (mem_ref[i]) strvar = { strvar, $sformatf("%2h ", mem_ref[i]) };
        ev = uvm_event_pool::get_global_pool().get("EV_DUMP");
        ev.trigger();
        uvm_report_info(get_name(), $sformatf("Reference mem: [%s]", strvar));
        uvm_report_info(get_name(), $sformatf("-------------------"));
    endfunction
endclass
    