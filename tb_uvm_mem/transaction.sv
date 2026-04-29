`include "uvm_macros.svh"
import uvm_pkg::*;
import risc_pkg::*;


class transaction extends uvm_sequence_item;
    parameter WIDTH = mem_config::DATA_WIDTH;

    randc op_enum_dmem_size blsize;
    rand bit wen;
    rand bit ren;
    rand bit [mem_config::ADDR_WIDTH-1:0] addr;
    rand bit [WIDTH-1:0] wr_data;
    bit [WIDTH-1:0] rd_data;

    `uvm_object_utils_begin (transaction)
        `uvm_field_enum (op_enum_dmem_size, blsize, UVM_DEFAULT)
        `uvm_field_int (wen, UVM_DEFAULT)
        `uvm_field_int (ren, UVM_DEFAULT)
        `uvm_field_int (addr, UVM_DEFAULT)
        `uvm_field_int (wr_data, UVM_DEFAULT)
        `uvm_field_int (rd_data, UVM_DEFAULT)
    `uvm_object_utils_end

    constraint c_addr { addr % 4 == 0; };
    constraint c_addr_depth { addr < mem_config::DEPTH; };
    constraint c_wr_rd { wen ^ ren; };
    constraint c_blsize {
        if (WIDTH < 16) {
            blsize inside {OP_DMEM_BYTE};
        } else if (WIDTH < 24) {
            blsize inside {OP_DMEM_BYTE, OP_DMEM_HALF};
        } else if (WIDTH < 32) {
            blsize inside {OP_DMEM_BYTE, OP_DMEM_HALF, OP_DMEM_TRPL};
        } else if (WIDTH < 64) {
            !(blsize inside {OP_DMEM_DUBL, OP_DMEM_QUAD});
        } else if (WIDTH < 128) {
            !(blsize inside {OP_DMEM_QUAD});
        }
    }
    // TODO: For now not verifying out of bound addresses 
    constraint c_addr_limit {
        if (mem_config::DEPTH - addr < 16) !(blsize inside {OP_DMEM_QUAD});
    }

    function new(string name="seq_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string s = "blsize=%s wen=%0b ren=%0b addr=0x%0h wr_data=0x%0h rd_data=0x%0h";
        return $sformatf(s, blsize.name(), wen, ren, addr, wr_data, rd_data);
    endfunction
endclass

