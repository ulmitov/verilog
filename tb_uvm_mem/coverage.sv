`include "uvm_macros.svh"
import uvm_pkg::*;


class coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(coverage)
    transaction req;

    covergroup cg_data; 
        option.per_instance = 1;
        // Block sizes
        cp_bl_size: coverpoint req.blsize {
            bins mem_sizes[] = {0, 1, 2, 3, 4, 7};
        }
        // Address coverage
        cp_addr_rd: coverpoint req.addr iff (req.ren) {
            bins read_address_range = {[0:mem_config::DEPTH]};
            bins each_bit[] = {[0:mem_config::ADDR_WIDTH-1]};
        }
        cp_addr_wr: coverpoint req.addr iff (req.wen) {
            bins write_address_range = {[0:mem_config::DEPTH]};
            bins each_bit[] = {[0:mem_config::ADDR_WIDTH-1]};
        }
        // Data Coverage
        cp_data_rd: coverpoint req.rd_data iff (req.ren) {
            bins zero = {0};
            bins ones = {{mem_config::DATA_WIDTH{1'b1}}};
            bins each_bit[] = {[0:mem_config::ADDR_WIDTH-1]};
        }
        cp_data_wr: coverpoint req.wr_data iff (req.wen) {
            bins zero = {0};
            bins ones = {{mem_config::DATA_WIDTH{1'b1}}};
            bins each_bit[] = {[0:mem_config::ADDR_WIDTH-1]};
        }
        cp_rd: cross cp_addr_rd, cp_data_rd {
            ignore_bins ignore_eachbit = binsof(cp_addr_rd.each_bit) && binsof(cp_data_rd.each_bit);
        }
        cp_wr: cross cp_addr_wr, cp_data_wr {
            ignore_bins ignore_eachbit = binsof(cp_addr_wr.each_bit) && binsof(cp_data_wr.each_bit);
        }
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
