/*
    Generating the stimulus by randomizing the transaction class
    Sending the randomized class to driver
*/
import risc_pkg::*;


class generator;
    mailbox #(transaction) gen2drv_mail;
    rand transaction t;
    int count = 0;

    function new(mailbox #(transaction) mb);
        this.gen2drv_mail = mb;
    endfunction

    task rand_vals(int num);
        int res;
        repeat(num) begin
            this.count++;
            $display("TRANS No.%0d:", this.count);
            t = new();
            res = t.randomize();
            if (!res) $fatal("Generator:: randomization failed");
            t.display("GEN");
            this.gen2drv_mail.put(t);
        end
    endtask

    task rand_bits_add(int num);
        /*
        Toggle same bit in a and b while b is togggled also with another lower bit
        */
        int res;

        repeat(num) begin
            this.count++;
            $display("TRANS No.%0d:", this.count);
            t = new();
            res = t.randomize() with { $countones(alu_a) == 1 && alu_b == (alu_a | (alu_a << 1)); };
            if (!res) $fatal("Generator:: randomization failed");
            t.alu_op = op_enum_alu'(OP_ALU_ADD);
            t.display("GEN");
            this.gen2drv_mail.put(t);
        end
    endtask

    task rand_bits_non_add(int num);
        /*
        Toggle single bits in a and b
        */
        int res;
        op_enum_alu opcode;
        repeat(num) begin
            this.count++;
            $display("TRANS No.%0d:", this.count);
            t = new();
            res = t.randomize() with { $countones(alu_a) == 1 && $countones(alu_b) == 1 && alu_a != alu_b; };
            //if (!res) $fatal("Generator:: randomization failed");
            std::randomize(opcode) with { opcode != OP_ALU_ADD; };
            t.alu_op = opcode;
            t.display("GEN");
            this.gen2drv_mail.put(t);
        end
    endtask

    task set(input [31:0] a, b, int opcode = -1);
        /*
        Set a, b and opcode manually (or randomize opcode)
        */
        int res;
        op_enum_alu op;
        this.count++;
        $display("TRANS No.%0d:", this.count);
        t = new();
        if (opcode == -1) begin
            res = std::randomize(op);
            t.alu_op = op;
            if (!res) $fatal("Generator:: randomization failed");
        end else
            t.alu_op = op_enum_alu'(opcode);
        t.alu_a = a;
        t.alu_b = b;
        t.display("GEN");
        this.gen2drv_mail.put(t);
    endtask
endclass
