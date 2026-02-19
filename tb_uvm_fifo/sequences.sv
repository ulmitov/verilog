/*
    Sequences (Sequencer generator to driver)
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


class sequence_manual extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_manual)

    function new(string name = "sequence_manual");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING MANUAL TRANSACTIONS -------");
        req = transaction::type_id::create("req");
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == {fifo_config::FIFO_DEPTH{1'b1}}; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == 0; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == {fifo_config::FIFO_DEPTH{1'b1}}; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
    endtask
endclass


// random transactions
class sequence_rand extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_rand)

    function new(string name = "sequence_rand");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING RANDOM TRANSACTIONS -------");
        req = transaction::type_id::create("req");
        repeat(fifo_config::SEQ_REPEAT) begin
            wait_for_grant();   // from driver
            assert(req.randomize() with {req.push dist { 1 := 7, 0 := 3 };});
            send_request(req);
            wait_for_item_done();
        end
    endtask
endclass


// write then read
class sequence_wr_rd extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_wr_rd)

    function new(string name = "sequence_wr_rd");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING WRITE THEN READ TRANSACTIONS -------");
        req = transaction::type_id::create("req");
        repeat(fifo_config::SEQ_REPEAT) begin
            `uvm_do_with(req, {req.push == 1; req.pull == 0;})
            `uvm_do_with(req, {req.push == 0; req.pull == 1;})
        end
    endtask
endclass


// write only
class sequence_wr extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_wr)

    int seq_single;

    function new(string name = "sequence_wr");
        super.new(name);
        if (!uvm_config_db #(int)::get(null, "", "seq_single", seq_single))
            uvm_report_fatal(get_name(), "seq_single is not in db");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING WRITE ONLY TRANSACTIONS -------");
        req = transaction::type_id::create("req");
        repeat(seq_single) begin
            start_item(req);
            assert(req.randomize() with { 
                req.pull == 0;
                req.push == 1;
                $countones(req.din) == 1 || req.din == 0 || req.din == {fifo_config::DATA_WIDTH{1'b1}};
            });
            finish_item(req);
        end
    endtask
endclass


// read only
class sequence_rd extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_rd)

    int seq_single;

    function new(string name = "sequence_rd");
        super.new(name);
        if (!uvm_config_db #(int)::get(null, "", "seq_single", seq_single))
            uvm_report_fatal(get_name(), "seq_single is not in db");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING READ ONLY TRANSACTIONS -------");
        req = transaction::type_id::create("req");
        repeat(seq_single)
            `uvm_do_with(req, { req.push == 0; req.pull == 1; })
    endtask
endclass


// multiple writes then multiple reads
class sequence_wr_rd_mult extends uvm_sequence#(transaction);
    `uvm_object_utils(sequence_wr_rd_mult)

    sequence_rd rds;
    sequence_wr wrs;

    function new(string name = "sequence_wr_rd_mult");
        super.new(name);
        wrs = sequence_wr::type_id::create("WRS");
        rds = sequence_rd::type_id::create("RDS");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING MULTIPLE WRITE THEN READ TRANSACTIONS -------");
        repeat(fifo_config::SEQ_REPEAT) begin
            `uvm_do_with(wrs, {})
            `uvm_do_with(rds, {})
        end
    endtask
endclass
