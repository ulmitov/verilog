`ifdef VERILATOR
`define VIF vif         // TBD: remove after verilator modport issues fixed
`else
`define VIF vif.mod_mon
`endif


class monitor;
    mailbox #(transaction) mon2scb_mail;
    transaction req;
    virtual intf vif;

    function new(virtual intf vif_init, mailbox #(transaction) mb);
        vif = vif_init;
        mon2scb_mail = mb;
    endfunction

    task main(int num);
        repeat(num) begin
            req = new();
            // lock VIF to avoid driver access
            `ifdef VERILATOR
            @(negedge `VIF.clk) vif.lock();
            $display("MON locked drv");
            `else
            vif.lock();
            `endif
            req.alu_a = `VIF.alu_a;
            req.alu_b = `VIF.alu_b;
            req.alu_op = `VIF.alu_op;
            req.alu_res = `VIF.alu_res;
            req.res_exp = `VIF.res_exp;
            vif.unlock();
            mon2scb_mail.put(req);
            req.display("MON");
        end
    endtask
endclass
