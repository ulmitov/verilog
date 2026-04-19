class scoreboard;
    `ifndef VERILATOR
    coverage cov;
    `endif
    mailbox #(transaction) mon2scb_mail;
    transaction trans;
    int count = 0;
    int fails = 0;

    function new (mailbox #(transaction) mb);
        mon2scb_mail = mb;
        `ifndef VERILATOR
        cov = new();
        `endif
    endfunction

    task main(int num);
        trans = new();
        repeat(num) begin
            #1 mon2scb_mail.get(trans);
            assert(trans.alu_res !== 32'bX && trans.alu_res !== 32'bZ)
            else $error("ERROR: ALU RESULT is invalid");
            if (trans.alu_res == trans.res_exp)
                trans.display("SCB");
            else begin
                $display("----------------------");
                trans.display("SCB: ERROR");
                $display("----------------------");
                fails++;
            end
            count++;
            `ifndef VERILATOR
            cov.sample(trans);
            `endif
        end
    endtask
endclass
