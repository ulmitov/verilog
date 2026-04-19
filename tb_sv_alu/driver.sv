`ifdef VERILATOR
`define VIF vif         // TBD: remove after modport issues fixed
`else
`define VIF vif.mod_drv
`endif


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
            // lock VIF from all threads until alu produces result
            `ifdef VERILATOR
            @(posedge vif.clk) vif.lock();
            $display("DRV LOCKED");
            `else
            vif.lock();
            `endif
            `VIF.alu_a = req.alu_a;
            `VIF.alu_b = req.alu_b;
            `VIF.alu_op = req.alu_op;
            req.display("DRV");
            `ifdef VERILATOR
            @(negedge vif.clk) vif.unlock();
            $display("DRV UNLOCK");
            `else
                `ifdef TPD
                #`TPD vif.unlock();
                `endif
            `endif
        end
    endtask
endclass
