class generator;
    mailbox #(transaction) gen2drv_mail;
    rand transaction req;
    int count = 0;
    int res;

    function new(mailbox #(transaction) mb);
        gen2drv_mail = mb;
    endfunction

    /*
        Generate fully random sequences
    */
    task rand_vals(int num);
        repeat(num) begin
            count++;
            $display("TRANS No.%0d:", count);
            req = new();
            res = req.randomize();
            if (!(|res)) $fatal("Generator:: randomization failed");
            req.display("GEN");
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Toggle same bit in a and b while b is togggled also with another lower bit
    */
    task rand_bits_add(int num);
        repeat(num) begin
            count++;
            $display("TRANS No.%0d:", count);
            req = new();
            res = req.randomize() with { $countones(alu_a) == 1 && alu_b == (alu_a | (alu_a << 1)); };
            if (!(|res)) $fatal("Generator:: randomization failed");
            req.alu_op = op_enum_alu'(OP_ALU_ADD);
            req.display("GEN");
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Toggle single bits in a and b
    */
    task rand_bits_non_add(int num);
        op_enum_alu opcode;
        repeat(num) begin
            count++;
            $display("TRANS No.%0d:", count);
            req = new();
            res = req.randomize() with { $countones(alu_a) == 1 && $countones(alu_b) == 1 && alu_a != alu_b; };
            if (!(|res)) $fatal("Generator:: randomization failed");
            if (!(|std::randomize(opcode) with { opcode != OP_ALU_ADD; }))
                $error("[ALU] ERROR: failed to randomize transaction");
            req.alu_op = opcode;
            req.display("GEN");
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Set a, b and opcode manually (or randomize opcode)
    */
    task set(input [31:0] a, b, int opcode = -1);
        op_enum_alu op;
        count++;
        $display("TRANS No.%0d:", count);
        req = new();
        if (opcode == -1) begin
            if (!(|std::randomize(op))) $fatal("Generator:: randomization failed");
            req.alu_op = op;
        end else
            req.alu_op = op_enum_alu'(opcode);
        req.alu_a = a;
        req.alu_b = b;
        req.display("GEN");
        gen2drv_mail.put(req);
    endtask

    task manual(int num);
        repeat(num) begin
            set(0, 0);
            set({32{1'b1}}, {32{1'b1}});
            set(0, 0);
            set({{16{1'b0}}, {16{1'b1}}}, {{17{1'b0}}, {15{1'b1}}});
            set({{16{1'b1}}, {16{1'b0}}}, {1'b0, {15{1'b1}}, {16{1'b0}}});
        end
    endtask
endclass
