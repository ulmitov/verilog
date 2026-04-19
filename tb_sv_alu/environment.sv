`include "intf.sv"
`include "transaction.sv"
`ifndef VERILATOR
`include "coverage.sv"
`endif
`include "generator.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"


class environment;
    virtual intf vif;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mail;
    mailbox #(transaction) mon2scb_mail;

    function new(virtual intf vif_init);
        vif = vif_init;
        gen2drv_mail = new();
        mon2scb_mail = new();
        gen = new(gen2drv_mail);
        scb = new(mon2scb_mail);
        drv = new(vif, gen2drv_mail);
        mon = new(vif, mon2scb_mail);
    endfunction

    task test_random_val(int num);
        $display("Testing random inputs: functionality test");
        fork
            gen.rand_vals(num);
            drv.main(num);
            mon.main(num);
            scb.main(num);
        join
    endtask

    task test_bit_by_bit(int num);
        $display("Testing a and b toggled bit by bit only for ADD operation to check sum and carry of each FA at each stage");
        fork
            gen.rand_bits_add(num);
            drv.main(num);
            mon.main(num);
            scb.main(num);
        join
    endtask

    task test_random_bit(int num);
        $display("Testing bits randomly toggled in a and b for all opcodes except for ADD: this will check the shifts, xors and the rest");
        fork
            gen.rand_bits_non_add(num);
            drv.main(num);
            mon.main(num);
            scb.main(num);
        join
    endtask

    task test_manual_val();
        int i;
        int num = 10; // as amount of opcodes
        $display("Testing manual inputs: checking stuck 1's or 0's, crosstalk and boundary values");
        fork
            gen.manual(num);   // each time have 5 transaction
            drv.main(num * 5);
            mon.main(num * 5);
            scb.main(num * 5);
        join
    endtask

    task pre_test();
        $display("Pre test run");
    endtask

    task post_test();
        $display("Post test run");
        `ifndef VERILATOR
        scb.cov.print();
        `endif
        assert(scb.count)
        else $error("Scoreboard: Got 0 transactions");
        assert(scb.count == gen.count)
            $display("Scoreboard: proccessed all %0d transactions", gen.count);
        else
            $error("Scoreboard: %d scb count is not %d", scb.count, gen.count);
        assert(scb.fails == 0)
            $display("Scoreboard: PASSED");
        else
            $display("Scoreboard: FAILED: %0d transaction errors", scb.fails);
    endtask
endclass
