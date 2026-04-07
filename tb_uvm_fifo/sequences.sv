/*
    Transaction Sequences sent by Sequencer generator to driver
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


/* Base class with all kinds of sequences */
class base_sequence extends uvm_sequence#(transaction);
    `uvm_object_utils(base_sequence)

    transaction req;
    int num_to_full;
    int default_repeats;

    function new(string name = "SEQ_BASE");
        super.new(name);
        default_repeats = fifo_config::SEQ_REPEAT;
    endfunction

    virtual task pre_start();
        super.pre_start();
		req = transaction::type_id::create();
        if (!uvm_config_db#(int)::get(null, "", "num_to_full", num_to_full))
            uvm_report_fatal(get_name(), "num_to_full is not in db");
	endtask

    function void header(string txt, int num);
        if (num > 1)
            uvm_report_info(get_name(),
                $sformatf("--- STARTING TRANSACTIONS: %s (%0d total) ---", txt, num));
    endfunction
    virtual task seq_pull(input int repeats = 1);
        header("pull only", repeats);
        repeat(repeats) begin
            if (!req.randomize() with { push == 0; pull == 1; })
                uvm_report_error(get_name(), "Failed to randomize");
        end
    endtask

    virtual task seq_push_00(input int repeats = 1);
        header("push 0x00", repeats);
        repeat(repeats) begin
            start_item(req);
            if (!req.randomize() with { pull == 0; push == 1; din == 0; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_push_ff(input int repeats = 1);
        header("push 0xFF", repeats);
        repeat(repeats) begin
            start_item(req);
            if (!req.randomize() with { 
                pull == 0; push == 1; din == {fifo_config::DATA_WIDTH{1'b1}}; 
            })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_push_bits(input int repeats = 1);
        header("push single bits", repeats);
        repeat(repeats) begin
            start_item(req);
            if (!req.randomize() with { pull == 0; push == 1; $countones(din) == 1; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_push_random(input int repeats = 1);
        header("push random data", repeats);
        repeat(repeats) begin
            start_item(req);
            if (!req.randomize() with { pull == 0; push == 1; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_random(input int repeats = 1);
        header("fully random", repeats);
        repeat(repeats) begin
            if (!req.randomize() with { push dist { 1 := 7, 0 := 3 }; })
                uvm_report_error(get_name(), "Failed to randomize");
        end
    endtask

    virtual task seq_parallel(input int repeats = 1);
        bit [fifo_config::DATA_WIDTH-1:0] data = 0;
        header("push+pull in parallel", repeats);
        repeat(repeats) begin
            data = ~data;
            if (!req.randomize() with { req.push == 1; req.pull == 1; req.din == data; })
                uvm_report_error(get_name(), "Failed to randomize");
        end
    endtask
endclass


class seq_lib extends uvm_sequence_library #(transaction);
    `uvm_object_utils(seq_lib)
    `uvm_sequence_library_utils(seq_lib)
    function new(string name = "SEQ_LIB");
        super.new(name);
        selection_mode = UVM_SEQ_LIB_USER;
        min_random_count = 1;
        max_random_count = 7;
        add_sequence(sequence_push_pull_00::get_type());
        add_sequence(sequence_push_pull_ff::get_type());
        add_sequence(sequence_consecutives_while_empty::get_type());
        add_sequence(sequence_consecutives_while_full::get_type());
        add_sequence(sequence_parallel::get_type());
        add_sequence(sequence_rand::get_type());
        init_sequence_library();
    endfunction
    function int unsigned select_sequence(int unsigned max);
        // Overriding, since for some reason uvm 1.2 passes max minus 1, so last index will never run!
        static int unsigned counter = 0;
        select_sequence = counter;
        counter++;
        if (counter > max) counter = 0;
    endfunction
endclass


class sequence_rand extends base_sequence;
    `uvm_object_utils(sequence_rand)
    function new(string name = "SEQ_random");
        super.new(name);
    endfunction
    task body;
        seq_random(default_repeats);
    endtask
endclass


class sequence_parallel extends base_sequence;
    `uvm_object_utils(sequence_parallel)
    function new(string name = "SEQpar");
        super.new(name);
    endfunction
    task body;
        seq_pull(fifo_config::FIFO_DEPTH);
        seq_parallel();
        repeat(fifo_config::FIFO_DEPTH / 2) begin
            seq_push_00();
            seq_push_ff();
        end
        seq_parallel(fifo_config::FIFO_DEPTH * 2);
    endtask
endclass


class sequence_consecutives_while_empty extends base_sequence;
    `uvm_object_utils(sequence_consecutives_while_empty)
    function new(string name = "SEQ_consecutives");
        super.new(name);
    endfunction
    task body;
        seq_pull(fifo_config::FIFO_DEPTH);
        header("consecutive push-pull while empty", num_to_full);
        repeat(num_to_full) begin
            seq_push_bits();
            seq_pull();
        end
    endtask
endclass


class sequence_consecutives_while_full extends base_sequence;
    `uvm_object_utils(sequence_consecutives_while_full)
    function new(string name = "SEQ_consecutives");
        super.new(name);
    endfunction
    task body;
        seq_push_bits(fifo_config::FIFO_DEPTH);
        header("consecutive push-pull while full", num_to_full);
        repeat(num_to_full) begin
            seq_push_bits();
            seq_pull();
        end
    endtask
endclass


class sequence_push_pull_00 extends base_sequence;
    `uvm_object_utils(sequence_push_pull_00)
    function new(string name = "SEQ_00");
        super.new(name);
    endfunction
    task body;
        default_repeats = 2;
        header($sformatf("push 00 and pull %0d times", num_to_full), default_repeats);
        repeat(default_repeats) begin
            seq_push_00(num_to_full);
            seq_pull(num_to_full);
        end
    endtask
endclass


class sequence_push_pull_ff extends base_sequence;
    `uvm_object_utils(sequence_push_pull_ff)
    function new(string name = "SEQ_FF");
        super.new(name);
    endfunction
    task body;
        default_repeats = 2;
        header($sformatf("push FF and pull %0d times", num_to_full), default_repeats);
        repeat(default_repeats) begin
            seq_push_ff(num_to_full);
            seq_pull(num_to_full);
        end
    endtask
endclass


class sequence_push_pull_FF_00 extends base_sequence;
    `uvm_object_utils(sequence_push_pull_FF_00)
    function new(string name = "SEQ_FF_00");
        super.new(name);
    endfunction
    task body;
        header("push-pull 00 and FF", num_to_full);
        repeat(num_to_full) begin
            seq_push_ff();
            seq_pull();
            seq_push_00();
            seq_pull();
        end
    endtask
endclass
