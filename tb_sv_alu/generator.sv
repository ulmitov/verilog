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
        int reps [$] = {};
        repeat(num) begin
            req = new();
            count++;
            res = req.randomize() with { !(alu_a inside {reps}) && !(alu_b inside {reps}); };
            if (!(|res)) $fatal("Generator:: randomization failed");
            reps.push_back(req.alu_a);
            reps.push_back(req.alu_b);
            req.display($sformatf("GEN #%0d", count), 0);
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Toggle same bit in a and b while b is togggled also with another lower bit
    */
    task toogle_bits_add();
        for (int i = 0; i < RISCV_XLEN; i = i + 1) begin
            req = new();
            count++;
            req.alu_a = 2 ** i;
            req.alu_b = req.alu_a + (req.alu_a >> 1);
            req.alu_op = op_enum_alu'(OP_ALU_ADD);
            req.display($sformatf("GEN #%0d", count), 0);
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Toggle single bits in a and b
    */
    task rand_bits_non_add(int num);
        op_enum_alu opcode;
        repeat(num) begin
            req = new();
            count++;
            res = req.randomize() with { 
                $countones(alu_a) == 1 &&
                $countones(alu_b) == 1 &&
                alu_a != alu_b; 
            };
            if (!(|res)) $fatal("Generator:: randomization failed");
            if (!(|std::randomize(opcode) with { opcode != OP_ALU_ADD; }))
                $error("[ALU] ERROR: failed to randomize transaction");
            req.alu_op = opcode;
            req.display($sformatf("GEN #%0d", count), 0);
            gen2drv_mail.put(req);
        end
    endtask

    /*
        Set a, b and opcode manually (or randomize opcode)
    */
    task set(input [RISCV_XLEN-1:0] a, b, int opcode = -1);
        op_enum_alu op;
        req = new();
        if (opcode == -1) begin
            if (!(|std::randomize(op))) $fatal("Generator:: randomization failed");
            req.alu_op = op;
        end else
            req.alu_op = op_enum_alu'(opcode);
        req.alu_a = a;
        req.alu_b = b;
        gen2drv_mail.put(req);
        count++;
        req.display($sformatf("GEN #%0d", count), 0);
    endtask

    task manual(int num);
        repeat(num) begin
            set(0, 0);
            set({RISCV_XLEN{1'b1}}, {RISCV_XLEN{1'b1}});
            set(0, 0);
            set({{(RISCV_XLEN/2){1'b0}}, {(RISCV_XLEN/2){1'b1}}}, {{((RISCV_XLEN/2) + 1){1'b0}}, {((RISCV_XLEN/2) - 1){1'b1}}});
            set({{(RISCV_XLEN/2){1'b1}}, {(RISCV_XLEN/2){1'b0}}}, {1'b0, {((RISCV_XLEN/2) - 1){1'b1}}, {(RISCV_XLEN/2){1'b0}}});
            set({{(RISCV_XLEN/2){2'b10}}}, {{(RISCV_XLEN/2){2'b10}}});
            set({{(RISCV_XLEN/2){2'b01}}}, {{(RISCV_XLEN/2){2'b01}}});
        end
    endtask
endclass
