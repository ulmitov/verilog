import risc_pkg::*;


class transaction;
    `ifdef VERILATOR
    rand op_enum_alu alu_op;
    `else
    randc op_enum_alu alu_op;
    `endif
    rand bit [RISCV_XLEN-1:0] alu_a;
    rand bit [RISCV_XLEN-1:0] alu_b;
    logic [RISCV_XLEN-1:0] alu_res;
    logic [RISCV_XLEN-1:0] res_exp;   // ALU reference model result

    function void display(string name, bit full = 1);
        if (full)
            $display("%5dns %s: %11s (op=%0d): A=0x%h, B=0x%h, RES=0x%h, EXP=0x%h",
                    $time, name, alu_op.name(), alu_op, alu_a, alu_b, alu_res, res_exp);
        else
            $display("%5dns %s: %11s (op=%0d): A=0x%h, B=0x%h",
                    $time, name, alu_op.name(), alu_op, alu_a, alu_b);
    endfunction
endclass
