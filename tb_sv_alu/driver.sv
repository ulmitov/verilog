`include "consts.v"
`define T_DELAY (`T_DELAY_PD*(3*32))


class driver;
    mailbox #(transaction) gen2drv_mail;
    virtual intf vif;

    function new(virtual intf vif_init, mailbox #(transaction) mb);
        this.vif = vif_init;
        this.gen2drv_mail = mb;
    endfunction

    task main(int num);
        repeat(num) begin
            transaction trans;
            this.gen2drv_mail.get(trans);
            trans.display("DRV");
            // lock IF from all threads until alu produces result
            this.vif.lock();
            this.vif.mod_drv.alu_a <= trans.alu_a;
            this.vif.mod_drv.alu_b <= trans.alu_b;
            this.vif.mod_drv.alu_op <= trans.alu_op;
            #`T_DELAY this.vif.unlock();
        end
    endtask
endclass
