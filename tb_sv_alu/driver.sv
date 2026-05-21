`define DIF vif.mod_drv


class driver;
    mailbox #(transaction) gen2drv_mail;
    transaction req;
    virtual intf vif;

    function new(virtual intf vif_init, mailbox #(transaction) mb);
        vif = vif_init;
        gen2drv_mail = mb;
    endfunction

    task main(int num);
        repeat(num) begin
            gen2drv_mail.get(req);
            // lock DIF from all threads until alu produces result
            vif.lock();
            `DIF.alu_a = req.alu_a;
            `DIF.alu_b = req.alu_b;
            `DIF.alu_op = req.alu_op;
            #`TPD vif.unlock();
            req.display("DRV");
        end
    endtask
endclass
