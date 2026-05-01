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
    int bus_blocks = mem_config::BUS_BLOCKS;
    int default_repeats;
    int num_to_full;
    op_enum_dmem_size maxbl;

    function new(string name = "SEQ_BASE");
        super.new(name);
        default_repeats = mem_config::SEQ_REPEAT;
        maxbl = get_op_block_size(bus_blocks);
    endfunction

    function op_enum_dmem_size get_op_block_size(int unsigned blocks);
        op_enum_dmem_size opbl;
        case (blocks)
            01: opbl = op_enum_dmem_size'(OP_DMEM_BYTE);
            02: opbl = op_enum_dmem_size'(OP_DMEM_HALF);
            03: opbl = op_enum_dmem_size'(OP_DMEM_TRPL);
            04: opbl = op_enum_dmem_size'(OP_DMEM_WORD);
            08: opbl = op_enum_dmem_size'(OP_DMEM_DUBL);
            16: opbl = op_enum_dmem_size'(OP_DMEM_QUAD);
        endcase
        return opbl;
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
        header("Fully randomized", repeats);
        repeat(repeats) begin
            start_item(req);
            req.c_blsize.constraint_mode(0);
            req.c_addr_val.constraint_mode(0);                          // TODO: should it be on?
            if (!req.randomize())
                uvm_report_error(get_name(), "Failed to randomize all fields");
            finish_item(req);
        end
    endtask

    virtual task seq_per_byte_reads(input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header("Read all memory byte by byte", repeats);
        for (int i = 0; i < repeats; i = i + 1) begin
            start_item(req);
            req.c_addr_val.constraint_mode(0);
            if (!req.randomize() with { wen == 0; ren == 1; blsize == op_enum_dmem_size'(OP_DMEM_BYTE); addr == i; })
                uvm_report_error(get_name(), "Failed to randomize byte read");
            finish_item(req);
        end
    endtask

    virtual task seq_fill(input int wr_value, input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header($sformatf("Fill byte by byte with 0x%0h", wr_value), repeats);
        for (int i = 0; i < repeats; i = i + 1) begin
            start_item(req);
            req.wr_data = wr_value;
            req.blsize = op_enum_dmem_size'(OP_DMEM_BYTE);
            req.wen = 1;
            req.addr = i;
            finish_item(req);
        end
    endtask

    virtual task seq_write_from_end();
        header("Write in opposite direction different block sizes", mem_config::DEPTH);
        for (int i = mem_config::DEPTH-1; i >= 0; i = i - 1) begin
            start_item(req);
            req.c_addr_val.constraint_mode(0);
            req.c_addr_limit.constraint_mode(0);
            if (!req.randomize() with { wen == 1; addr == i; (addr >= mem_config::DEPTH - 16) -> (blsize inside {OP_DMEM_BYTE}); })
                uvm_report_error(get_name(), "Failed to randomize write from end");
            finish_item(req);
        end
    endtask

    virtual task seq_read_all_maxbl();
        header("Read all data with maximum block width", mem_config::DEPTH);
        for (int i = 0; i < mem_config::DEPTH; i = i + bus_blocks) begin
            start_item(req);
            req.c_addr_val.constraint_mode(0);
            req.c_blsize.constraint_mode(0);
            if (!req.randomize() with { ren == 1; blsize == maxbl; addr == i; })
                uvm_report_error(get_name(), "Failed to randomize max block width");
            finish_item(req);
        end
    endtask

    virtual task seq_invalid(input int repeats = 0);
        if (!repeats) repeats = num_to_full;
        header("Invalid addresses", repeats);
        for (int i = 0; i < repeats; i = i + 1) begin
            start_item(req);
            req.c_addr_val.constraint_mode(0);
            req.c_addr_depth.constraint_mode(0);
            req.c_addr_limit.constraint_mode(0);
            if (!req.randomize() with { addr >= mem_config::DEPTH; })
                uvm_report_error(get_name(), "Failed to randomize invalid address");
            finish_item(req);
        end
    endtask

    virtual task seq_write(input int address, input bit [mem_config::DATA_WIDTH-1:0] data);
        start_item(req);
        req.ren = 0;
        req.wen = 1;
        req.blsize = maxbl;
        req.addr = address;
        req.wr_data = data;
        finish_item(req);
    endtask

    virtual task seq_read(input int address);
        start_item(req);
        req.ren = 1;
        req.wen = 0;
        req.blsize = maxbl;
        req.addr = address;
        finish_item(req);
    endtask
endclass


class seq_lib extends uvm_sequence_library #(transaction);
    `uvm_object_utils(seq_lib)
    `uvm_sequence_library_utils(seq_lib)
    function new(string name = "SEQ_LIB");
        super.new(name);
        selection_mode = UVM_SEQ_LIB_USER;
        min_random_count = 5;
        max_random_count = 10;
        add_sequence(sequence_invalid::get_type());
        add_sequence(sequence_alternating_data::get_type());
        add_sequence(sequence_write_opposite::get_type());
        add_sequence(sequence_stress_pattern::get_type());
        add_sequence(sequence_random::get_type());
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
        seq_read_all_maxbl();
    endtask
endclass


class sequence_alternating_data extends base_sequence;
    `uvm_object_utils(sequence_alternating_data)
    function new(string name = "SEQ_ALT");
        super.new(name);
    endfunction
    task body;
        bit [mem_config::DATA_WIDTH-1:0] data;
        header("Consequent write and read with alternating data bits (1st cycle)", (mem_config::DEPTH * 2));
        data = 0;
        seq_write(0, data);
        for (int i = bus_blocks; i < mem_config::DEPTH - bus_blocks; i = i + bus_blocks) begin
            data = ~data;
            seq_write(i, data);
            seq_read(i - bus_blocks);
        end
        header("Consequent write and read with alternating data bits (2nd cycle)", (mem_config::DEPTH * 2));
        data = -1;
        seq_write(0, data);
        for (int i = bus_blocks; i < mem_config::DEPTH - bus_blocks; i = i + bus_blocks) begin
            data = ~data;
            seq_write(i, data);
            seq_read(i - bus_blocks);
        end
    endtask
endclass


class sequence_write_opposite extends base_sequence;
    `uvm_object_utils(sequence_write_opposite)
    function new(string name = "SEQ_WR_RD");
        super.new(name);
    endfunction
    task body;
        seq_write_from_end();
        seq_read_all_maxbl();
    endtask
endclass


class sequence_read_all extends base_sequence;
    `uvm_object_utils(sequence_read_all)
    function new(string name = "SEQ_RD");
        super.new(name);
    endfunction
    task body;
        seq_read_all_maxbl();
    endtask
endclass


class sequence_stress_pattern extends base_sequence;
    `uvm_object_utils(sequence_stress_pattern)
    function new(string name = "SEQ_STRESS");
        super.new(name);
    endfunction
    task body;
        header("Write 0x55 and 0xAA to same address then read", mem_config::DEPTH);
        for (int i = bus_blocks; i < mem_config::DEPTH - bus_blocks; i = i + bus_blocks) begin
            seq_write(i, {(mem_config::DATA_WIDTH/2){2'b01}});
            seq_write(i, {(mem_config::DATA_WIDTH/2){2'b10}});
            seq_read(i);
        end
    endtask
endclass


class sequence_invalid extends base_sequence;
    `uvm_object_utils(sequence_invalid)
    function new(string name = "SEQ_INVALID");
        super.new(name);
    endfunction
    task body;
        seq_invalid(10);
    endtask
endclass
