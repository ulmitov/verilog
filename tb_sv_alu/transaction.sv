import risc_pkg::*;


class transaction;
    rand op_enum_alu alu_op;
    rand bit [31:0] alu_a;
    rand bit [31:0] alu_b;
    logic [31:0] alu_res;
    logic [31:0] res_exp;   // ALU reference model result

    function void display(string name);
        if (alu_res !== 32'bX)
            $display("%5dns %s: %11s (%0d): A=0x%h, B=0x%h, RES=0x%h, EXP=0x%h", $time, name, alu_op.name(), alu_op, alu_a, alu_b, alu_res, res_exp);
        else
            $display("%5dns %s: %11s (%0d): A=0x%h, B=0x%h", $time, name, alu_op.name(), alu_op, alu_a, alu_b);
    endfunction
endclass
