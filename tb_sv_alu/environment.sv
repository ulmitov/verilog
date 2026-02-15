`include "intf.sv"
`include "transaction.sv"
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
        this.vif = vif_init;
        this.gen2drv_mail = new();
        this.mon2scb_mail = new();
        this.gen = new(this.gen2drv_mail);
        this.scb = new(this.mon2scb_mail);
        this.drv = new(vif_init, this.gen2drv_mail);
        this.mon = new(vif_init, this.mon2scb_mail);
    endfunction

    task test_random_val(int num);
        $display("Testing random inputs - functionality test");
        fork
            this.gen.rand_vals(num);
            this.drv.main(num);
            this.mon.main(num);
            this.scb.main(num);
        join
    endtask

    task test_bit_by_bit(int num);
        $display("Testing a and b toggled bit by bit only for ADD operation to check sum and carry of each FA at each stage");
        fork
            this.gen.rand_bits_add(num);
            this.drv.main(num);
            this.mon.main(num);
            this.scb.main(num);
        join
    endtask

    task test_random_bit(int num);
        $display("Testing bits randomly toggled in a and b for all opcodes except for ADD - this will check the shifts, xors and the rest");
        fork
            this.gen.rand_bits_non_add(num);
            this.drv.main(num);
            this.mon.main(num);
            this.scb.main(num);
        join
    endtask

    task test_manual_val();
        int i;
        int num = 10; // as amount of opcodes
        $display("Testing manual inputs - checking stuck at 1's or 0's, crosstalk and boundary values");
        fork
            for (i = 0; i < num; i = i + 1) begin
                this.gen.set(0, 0);
                this.gen.set({32{1'b1}}, {32{1'b1}});
                this.gen.set({{16{1'b0}}, {16{1'b1}}}, {{17{1'b0}}, {15{1'b1}}});
                this.gen.set({{16{1'b1}}, {16{1'b0}}}, {1'b0, {15{1'b1}}, {16{1'b0}}});
            end
            num = num * 4;
            this.drv.main(num);
            this.mon.main(num);
            this.scb.main(num);
        join
    endtask

    task pre_test();
        $display("Pre test run");
    endtask

    task post_test();
        $display("Post test run");
        assert(this.scb.count == this.gen.count)
            $display("Scoreboard: proccessed all %0d transactions", this.gen.count);
        else
            $error("Scoreboard: %d scb count is not %d", this.scb.count, this.gen.count);
        assert(this.scb.fails == 0)
            $display("Scoreboard: PASSED");
        else
            $display("Scoreboard: FAILED");
    endtask
endclass
