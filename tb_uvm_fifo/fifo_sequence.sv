/*
    Sequence class (Generator to driver)
*/
`include "uvm_macros.svh"
import uvm_pkg::*;


// random transactions
class fifo_sequence extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence)

    function new(string name = "fifo_sequence");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING RANDOM TRANSACTIONS -------");
        req = fifo_transaction::type_id::create("req");
        repeat(fifo_config::SEQ_REPEAT) begin
            wait_for_grant(); // from driver
            assert(req.randomize() with {req.push dist { 1 := 6, 0 := 4 };});
            send_request(req);
            wait_for_item_done();
        end
    endtask
endclass


class fifo_sequence_manual extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_manual)

    function new(string name = "fifo_sequence_manual");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING MANUAL TRANSACTIONS -------");
        req = fifo_transaction::type_id::create("req");
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == {fifo_config::FIFO_DEPTH{1'b1}}; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == 0; })
        `uvm_do_with(req, { req.push == 1; req.pull == 0; din == {fifo_config::FIFO_DEPTH{1'b1}}; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
        `uvm_do_with(req, { req.push == 0; req.pull == 1; })
    endtask
endclass


// write then read
class fifo_sequence_wr_rd extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr_rd)

    function new(string name = "fifo_sequence_wr_rd");
        super.new(name);
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING WRITE THEN READ TRANSACTIONS -------");
        req = fifo_transaction::type_id::create("req");
        repeat(fifo_config::SEQ_REPEAT) begin
            `uvm_do_with(req, {req.push == 1; req.pull == 0;})
            `uvm_do_with(req, {req.push == 0; req.pull == 1;})
        end
    endtask
endclass


// write only
class fifo_sequence_wr extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr)

    int seq_single;

    function new(string name = "fifo_sequence_wr");
        super.new(name);
        if (!uvm_config_db #(int)::get(null, "", "seq_single", seq_single))
            uvm_report_fatal(get_name(), "seq_single is not in db");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING WRITE ONLY TRANSACTIONS -------");
        req = fifo_transaction::type_id::create("req");
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
class fifo_sequence_rd extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_rd)

    int seq_single;

    function new(string name = "fifo_sequence_rd");
        super.new(name);
        if (!uvm_config_db #(int)::get(null, "", "seq_single", seq_single))
            uvm_report_fatal(get_name(), "seq_single is not in db");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING READ ONLY TRANSACTIONS -------");
        req = fifo_transaction::type_id::create("req");
        repeat(seq_single)
            `uvm_do_with(req, { req.push == 0; req.pull == 1; })
    endtask
endclass


// multiple writes then multiple reads
class fifo_sequence_wr_rd_completely extends uvm_sequence#(fifo_transaction);
    `uvm_object_utils(fifo_sequence_wr_rd_completely)

    fifo_sequence_rd rds;
    fifo_sequence_wr wrs;

    function new(string name = "fifo_sequence_wr_rd_completely");
        super.new(name);
        wrs = fifo_sequence_wr::type_id::create("WRS");
        rds = fifo_sequence_rd::type_id::create("RDS");
    endfunction

    virtual task body();
        uvm_report_info(get_name(), "----- STARTING MULTIPLE WRITE THEN READ TRANSACTIONS -------");
        repeat(fifo_config::SEQ_REPEAT) begin
            `uvm_do_with(wrs, {})
            `uvm_do_with(rds, {})
        end
    endtask
endclass
