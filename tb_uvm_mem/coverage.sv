`include "uvm_macros.svh"
import uvm_pkg::*;
import risc_pkg::op_enum_dmem_size;


class coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(coverage)

    transaction req;
    op_enum_dmem_size msz_enum;

    covergroup cg_data; 
        option.per_instance = 1;
        // Block sizes
        cp_bl_size: coverpoint req.blsize {
            bins mem_sizes[] = {0, 1, 2, 3, 4, 7};
        }
        // Address coverage
        cp_addr_rd: coverpoint req.addr iff (req.ren) {
            bins read_address_range = {[0:mem_config::DEPTH]};
        }
        cp_addr_wr: coverpoint req.addr iff (req.wen) {
            bins write_address_range = {[0:mem_config::DEPTH]};
        }
        // Data Coverage
        cp_data_rd: coverpoint req.rd_data iff (req.ren) {
            bins zero = {0};
            bins ones = {{mem_config::DATA_WIDTH{1'b1}}};
        }
        cp_data_wr: coverpoint req.wr_data iff (req.wen) {
            bins zero = {0};
            bins ones = {{mem_config::DATA_WIDTH{1'b1}}};
        }
        cp_rd: cross cp_addr_rd, cp_data_rd;
        cp_wr: cross cp_addr_wr, cp_data_wr;
    endgroup

    function new(string name,uvm_component parent);
        super.new(name,parent);
        cg_data = new();
    endfunction: new

    function void write(transaction t);
        req = t;
        cg_data.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_info(get_name(), $sformatf("Coverage is %0.2f %%", cg_data.get_coverage()));
    endfunction
endclass
