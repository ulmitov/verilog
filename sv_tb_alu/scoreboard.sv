class scoreboard;
    mailbox #(transaction) mon2scb_mail;
    int count = 0;
    int fails = 0;

    function new (mailbox #(transaction) mb);
        this.mon2scb_mail = mb;
    endfunction

    task main(int num);
        transaction trans;
        repeat(num) begin
            #1 this.mon2scb_mail.get(trans);
            assert(trans.alu_res !== 32'bX && trans.alu_res !== 32'bZ)
            else $error("ALU RESULT is invalid");
            if (trans.alu_res == trans.res_exp)
                trans.display("SCB");
            else begin
                $display("----------------------");
                trans.display("SCB: FAIL");
                $display("----------------------");
                this.fails++;
            end
            this.count++;
        end
    endtask
endclass
