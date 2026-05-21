`define MIF vif.mod_mon


class monitor;
    mailbox #(transaction) mon2scb_mail;
    transaction req;
    virtual intf vif;
    int count = 0;

    function new(virtual intf vif_init, mailbox #(transaction) mb);
        vif = vif_init;
        mon2scb_mail = mb;
    endfunction

    task main(int num);
        repeat(num) begin
            req = new();
            count++;
            // lock MIF to avoid driver access
            vif.lock();
            req.alu_a = `MIF.alu_a;
            req.alu_b = `MIF.alu_b;
            req.alu_op = `MIF.alu_op;
            req.alu_res = `MIF.alu_res;
            req.res_exp = `MIF.res_exp;
            vif.unlock();
            mon2scb_mail.put(req);
            req.display($sformatf("MON %0d", count));
        end
    endtask
endclass
