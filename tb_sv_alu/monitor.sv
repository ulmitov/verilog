class monitor;
    virtual intf vif;
    mailbox #(transaction) mon2scb_mail;

    function new(virtual intf vif_init, mailbox #(transaction) mb);
        this.vif = vif_init;
        this.mon2scb_mail = mb;
    endfunction

    task main(int num);
        repeat(num) begin
            transaction trans;
            trans = new();
            // lock IF to avoid driver access
            this.vif.lock();
            trans.alu_a = this.vif.mod_mon.alu_a;
            trans.alu_b = this.vif.mod_mon.alu_b;
            trans.alu_op = this.vif.mod_mon.alu_op;
            trans.alu_res = this.vif.mod_mon.alu_res;
            trans.res_exp = this.vif.mod_mon.res_exp;
            this.vif.unlock();
            this.mon2scb_mail.put(trans);
            trans.display("MON");
        end
    endtask
endclass
