/*
    Transaction class (Sequence Item)
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class fifo_transaction #(parameter WORD_WIDTH = 8) extends uvm_sequence_item;

    rand bit push;
    rand bit pull;
    rand bit [WORD_WIDTH-1:0] din;
    bit [WORD_WIDTH-1:0] dout;
    bit empty;
    bit full;

    // Use utility macros to implement standard functions
    // like print, copy, clone, etc
    `uvm_object_utils_begin(fifo_transaction)
        `uvm_field_int (push, UVM_DEFAULT)
        `uvm_field_int (pull, UVM_DEFAULT)
        `uvm_field_int (din, UVM_DEFAULT)
        `uvm_field_int (dout, UVM_DEFAULT)
        `uvm_field_int (empty, UVM_DEFAULT)
        `uvm_field_int (full, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name="fifo_seq_item");
        super.new(name);
    endfunction

    virtual function void print(string name = "");
        if (name == "") name = get_name();
        uvm_report_info(name, $sformatf("push=%0b pull=%0b din=0x%0h dout=0x%0h empty=%0b full=%0b", push, pull, din, dout, empty, full), UVM_MEDIUM);
    endfunction
endclass
