class coverage;
    transaction req;

    // Data Coverage
    covergroup cg_alu;
        option.per_instance = 1;
        cp_opcode: coverpoint req.alu_op;
        cp_data_wr_a: coverpoint req.alu_a {
            bins zero = {0};
            bins ones = {{32{1'b1}}};
            bins low_to_high = (0 => {32{1'b1}});
            bins high_to_low = ({32{1'b1}} => 0);
            bins each_bit[] = {[31:0]};
        }
        cp_data_wr_b: coverpoint req.alu_b {
            bins zero = {0};
            bins ones = {{32{1'b1}}};
            bins low_to_high = (0 => {32{1'b1}});
            bins high_to_low = ({32{1'b1}} => 0);
            bins each_bit[] = {[31:0]};
        }
        cp_data_wr_res: coverpoint req.alu_res {
            bins zero = {0};
            bins ones = {{32{1'b1}}};
            bins low_to_high = (0 => {32{1'b1}});
            bins high_to_low = ({32{1'b1}} => 0);
            bins each_bit[] = {[31:0]};
        }
        cp_msb_a: coverpoint req.alu_a[31] {
            bins msb_high = {1};
            bins msb_low  = {0};
        }
        cp_msb_b: coverpoint req.alu_b[31] {
            bins msb_high = {1};
            bins msb_low  = {0};
        }
        cp_msb_res: coverpoint req.alu_res[31] {
            bins msb_high = {1};
            bins msb_low  = {0};
        }
        cp_cross_msb: cross cp_msb_a, cp_msb_b;
        cp_cross_op_msb: cross cp_opcode, cp_msb_res;
    endgroup

    function new;
        cg_alu = new();
        $display("Started Coverage");
    endfunction

    function void sample(transaction tr);
        req = tr;
        cg_alu.sample();
    endfunction

    function void stop;
        $display("Stopping Coverage");
        cg_alu.stop();
    endfunction

    function void print;
        $display("Total coverage: %0d", cg_alu.get_coverage());
    endfunction
endclass
