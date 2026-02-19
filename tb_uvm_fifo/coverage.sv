`include "uvm_macros.svh"
import uvm_pkg::*;

//Coverage Collector class
class coverage extends uvm_subscriber #(fifo_transaction);
    `uvm_component_utils(coverage)

    fifo_transaction req;

    covergroup control_cg;
        option.per_instance = 1;

        // Pulls
        pull_cp: coverpoint req.pull {
            bins none = {0};
            bins pull = {1};
        }

        // Pushes
        push_cp: coverpoint req.push {
            bins none = {0};
            bins push = {1};
        } 

        // empty case
        empty_cp: coverpoint req.empty {
            bins not_empty = {0};
            bins empty = {1};
        }

        // full case
        full_cp: coverpoint req.full {
            bins not_full = {0};
            bins full = {1};
        }

        pull_empty: coverpoint req.pull && req.empty;                    // Pull when empty
        push_full: coverpoint req.push && req.full;                      // Push when full
        pull_and_push: coverpoint req.pull && req.push;                  // Parallel push pull
        pull_and_push_full: coverpoint req.pull && req.push && req.full; // Parallel push pull when full
    endgroup
    // Data Coverage
    covergroup data_bits_cg; 
        option.per_instance = 1;
        data_wr_cp: coverpoint req.din {
            bins zero = {0};
            bins ones = {{fifo_config::DATA_WIDTH{1'b1}}};
            bins low_to_high = (0 => {fifo_config::DATA_WIDTH{1'b1}});
            bins high_to_low = ({fifo_config::DATA_WIDTH{1'b1}} => 0);
        }
    endgroup

    function new(string name,uvm_component parent);
        super.new(name,parent);
        control_cg = new();
        data_bits_cg = new();
    endfunction: new

    function void write(fifo_transaction t);
        req = t;
        control_cg.sample();
        data_bits_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_info(get_name(), $sformatf("Coverage for control bits is %0.2f %%", control_cg.get_coverage()));
        uvm_report_info(get_name(), $sformatf("Coverage for data bits is %0.2f %%", data_bits_cg.get_coverage()));
    endfunction
endclass
