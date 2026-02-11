/*
    Sequence class (Generator to driver)
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class fifo_sequence extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence)

    function new(string name = "fifo_sequence");
        super.new(name);
    endfunction

    virtual task body();
        repeat(100) begin
            req = fifo_transaction#()::type_id::create("req");
            wait_for_grant(); // from driver
            assert(req.randomize() with {req.push dist { 1 := 6, 0 := 7 };});
            send_request(req);
            wait_for_item_done();
        end
    endtask
endclass


class fifo_sequence_wr extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr)

    function new(string name = "fifo_sequence_wr");
        super.new(name);
    endfunction

    virtual task body();
        repeat(15) begin
            req = fifo_transaction#()::type_id::create("req");
            start_item(req); // from driver
            assert(req.randomize() with { req.pull == 0; req.push == 1; });
            finish_item(req);
        end
    endtask
endclass



class fifo_sequence_rd extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_rd)

    function new(string name = "fifo_sequence_rd");
        super.new(name);
    endfunction

    virtual task body();
        repeat(15) begin
            req = fifo_transaction#()::type_id::create("req");
            start_item(req); // from driver
            assert(req.randomize() with { req.pull == 1; req.push == 0; });
            finish_item(req);
        end
    endtask
endclass


class fifo_sequence_wr_rd extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr_rd)

    function new(string name = "fifo_sequence_wr_rd");
        super.new(name);
    endfunction

    virtual task body();
        repeat(15) begin
            req = fifo_transaction#()::type_id::create("req");
            `uvm_do_with(req, {req.push == 1; req.pull == 0;})
            `uvm_do_with(req, {req.push == 0; req.pull == 1;})
            set_response_queue_error_report_disabled(1);
        end
    endtask
endclass



class fifo_sequence_wr_rd_completely extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr_rd_completely)

    fifo_sequence_rd rd;
    fifo_sequence_wr wr;

    function new(string name = "fifo_sequence_wr_rd_completely");
        super.new(name);
    endfunction

    virtual task body();
        wr = fifo_sequence_wr::type_id::create("WR");
        rd = fifo_sequence_rd::type_id::create("RD");
        repeat(15) begin
            //`define uvm_do_with(SEQ_OR_ITEM,CONSTRAINTS) - so dont need this class
            `uvm_do_with(wr, {})
            `uvm_do_with(rd, {})
            //set_response_queue_error_report_disabled(1);
        end
    endtask
endclass
