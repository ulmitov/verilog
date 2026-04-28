`include "uvm_macros.svh"
import uvm_pkg::*;
import risc_pkg::*;


/* Sequnce generator class */
class sequencer extends uvm_sequencer#(transaction);
    `uvm_component_utils(sequencer)
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass


/* Base class with atomic sequences */
class base_sequence extends uvm_sequence#(transaction);
    `uvm_object_utils(base_sequence)

    transaction req;
    int num_to_full;
    int default_repeats;
    int maxbl;
    int mem_blocks = mem_config::DATA_WIDTH / 8;

    function new(string name = "SEQ_BASE");
        super.new(name);
        default_repeats = mem_config::SEQ_REPEAT;
        case (mem_blocks)
            1: maxbl = op_enum_dmem_size'(OP_DMEM_BYTE);
            2: maxbl = op_enum_dmem_size'(OP_DMEM_HALF);
            3: maxbl = op_enum_dmem_size'(OP_DMEM_TRPL);
            4: maxbl = op_enum_dmem_size'(OP_DMEM_WORD);
            8: maxbl = op_enum_dmem_size'(OP_DMEM_DUBL);
            16: maxbl = op_enum_dmem_size'(OP_DMEM_QUAD);
        endcase
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
    
    virtual task seq_random(input int repeats = 1);
        header("randomized", repeats);
        repeat(repeats) begin
            start_item(req);
            req.c_blsize.constraint_mode(0);
            if (!req.randomize())
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_per_byte_reads(input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header("Read all memory byte by byte", repeats);
        for (int i = 0; i < repeats; i = i + 1) begin
            start_item(req);
            req.c_addr.constraint_mode(0);
            if (!req.randomize() with { wen == 0; ren == 1; blsize == op_enum_dmem_size'(OP_DMEM_BYTE); addr == i; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_fill(input int wr_value, input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header($sformatf("Fill 0x%0h", wr_value), repeats);
        for (int i = 0; i < repeats; i = i + 1) begin
            start_item(req);
            req.wr_data = wr_value;
            req.blsize = op_enum_dmem_size'(OP_DMEM_BYTE);
            req.wen = 1;
            req.addr = i;
            finish_item(req);
        end
    endtask

    virtual task seq_wr_maxbl(input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header("Write data with maximum block width", repeats);
        for (int i = 0; i < repeats; i = i + mem_blocks) begin
            start_item(req);
            req.c_addr.constraint_mode(0);
            req.c_blsize.constraint_mode(0);
            if (!req.randomize() with { req.wen == 1; req.blsize == maxbl; addr == i; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask

    virtual task seq_rd_maxbl(input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header("Read data with maximum block width", repeats);
        for (int i = 0; i < repeats; i = i + mem_blocks) begin
            start_item(req);
            req.c_addr.constraint_mode(0);
            req.c_blsize.constraint_mode(0);
            if (!req.randomize() with { req.ren == 1; req.blsize == maxbl; addr == i; })
                uvm_report_error(get_name(), "Failed to randomize");
            finish_item(req);
        end
    endtask
endclass


class seq_lib extends uvm_sequence_library #(transaction);
    `uvm_object_utils(seq_lib)
    `uvm_sequence_library_utils(seq_lib)
    function new(string name = "SEQ_LIB");
        super.new(name);
        selection_mode = UVM_SEQ_LIB_USER;
        min_random_count = 4;
        max_random_count = 5;
        add_sequence(sequence_fill_00::get_type());
        add_sequence(sequence_fill_FF::get_type());
        add_sequence(sequence_random::get_type());
        add_sequence(sequence_wr_rd::get_type());
        init_sequence_library();
    endfunction
    `ifdef UVM_MAJOR_VERSION_1_2
    // Overriding, since for some reason uvm 1.2 passes max minus 1
    // so last index will never run! UVM 1.8 does not have this issue
    function int unsigned select_sequence(int unsigned max);
        static int unsigned counter = 0;
        select_sequence = counter;
        counter++;
        if (counter > max) counter = 0;
    endfunction
    `endif
endclass


class sequence_random extends base_sequence;
    `uvm_object_utils(sequence_random)
    function new(string name = "SEQ_random");
        super.new(name);
    endfunction
    task body;
        seq_random(default_repeats);
    endtask
endclass


class sequence_fill_00 extends base_sequence;
    `uvm_object_utils(sequence_fill_00)
    function new(string name = "SEQ_00");
        super.new(name);
    endfunction
    task body;
        seq_fill(8'h0);
        seq_per_byte_reads();
    endtask
endclass


class sequence_fill_FF extends base_sequence;
    `uvm_object_utils(sequence_fill_FF)
    function new(string name = "SEQ_FF");
        super.new(name);
    endfunction
    task body;
        seq_fill(8'hFF);
        seq_per_byte_reads();
    endtask
endclass


class sequence_wr_rd extends base_sequence;
    `uvm_object_utils(sequence_wr_rd)
    function new(string name = "SEQ_WR_RD");
        super.new(name);
    endfunction
    task body;
        seq_wr_maxbl();
        seq_rd_maxbl();
    endtask
endclass
