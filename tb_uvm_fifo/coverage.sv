/*
    Coverage Collector class
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class coverage extends uvm_subscriber #(transaction);
    `uvm_component_utils(coverage)

    transaction req;

    covergroup cg;
        option.per_instance = 1;

        // pulls
        cp_pull: coverpoint req.pull {
            bins pull = {1};
        }

        // pushes
        cp_push: coverpoint req.push {
            bins push = {1};
        } 

        // empty case
        cp_empty: coverpoint req.empty {
            bins empty = {1};
        }

        // full case
        cp_full: coverpoint req.full {
            bins full = {1};
        }

        // Data Coverage
        cp_data_rd: coverpoint req.dout iff (req.pull & ~req.empty) {
            bins zero = (0[*fifo_config::FIFO_DEPTH-1]);
            bins ones = ({fifo_config::DATA_WIDTH{1'b1}}[*fifo_config::FIFO_DEPTH-1]);
            bins low_to_high = (0 => {fifo_config::DATA_WIDTH{1'b1}});
            bins high_to_low = ({fifo_config::DATA_WIDTH{1'b1}} => 0);
        }

        pull_empty: cross cp_pull, cp_empty;
        push_full: cross cp_push, cp_full;
        pull_push: cross cp_push, cp_pull;
        pull_push_full: cross cp_push, cp_pull, cp_full;
        pull_push_empty: cross cp_push, cp_pull, cp_empty;
    endgroup

    function new(string name,uvm_component parent);
        super.new(name,parent);
        cg = new();
    endfunction: new

    function void write(transaction tr);
        req = tr;
        cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        uvm_report_info(get_name(), $sformatf("Coverage is %0.2f %%", cg.get_coverage()));
    endfunction
endclass
