import risc_pkg::*;


module alu #(parameter XLEN = 32) (
    input op_enum_alu alu_op,
    input logic [XLEN-1:0] alu_a,
    input logic [XLEN-1:0] alu_b,
    output logic [XLEN-1:0] alu_res
);
    `ifdef GATEFLOW
        logic eq, lt, ltu;
        logic nadd_sub, right_en, sign_ext;
        logic [XLEN-1:0] sum, out_sh;
        logic [5:0] shifts_num;

        adder #(XLEN) alu_fa (.Nadd_sub(nadd_sub), .X(alu_a), .Y(alu_b), .sum(sum), .carry(), .overflow(), .eq(eq), .lt(lt), .ltu(ltu));
        shift #(XLEN) alu_sh (.right_en(right_en), .sign(sign_ext), .din(alu_a), .shift_n(shifts_num), .out(out_sh));

        assign shifts_num = {1'b0, alu_b[4:0]};

        always_comb begin
            case (alu_op)
                OP_ALU_SLTU,
                OP_ALU_SLT,
                OP_ALU_SUB:     nadd_sub = 1'b1;
                default:        nadd_sub = 1'b0;
            endcase

            case (alu_op)
                OP_ALU_SRA,
                OP_ALU_SRL:     right_en = 1'b1;
                default:        right_en = 1'b0; // OP_ALU_SLL and the rest
            endcase

            case (alu_op)
                OP_ALU_SRA:     sign_ext = 1'b1;
                default:        sign_ext = 1'b0;
            endcase

            case (alu_op)
                OP_ALU_ADD,
                OP_ALU_SUB:     alu_res = sum;
                OP_ALU_SLL,
                OP_ALU_SRL,
                OP_ALU_SRA:     alu_res = out_sh;
                OP_ALU_XOR:     alu_res = alu_a ^ alu_b;
                OP_ALU_AND:     alu_res = alu_a & alu_b;
                OP_ALU_OR:      alu_res = alu_a | alu_b;
                OP_ALU_SLT:     alu_res = {XLEN{lt}};
                OP_ALU_SLTU:    alu_res = {XLEN{ltu}};
                default:        alu_res = {XLEN{1'b0}};
            endcase
        end
    `else
        alu_dataflow (.a(alu_op), .alu_a(alu_a), .alu_b(alu_b), .alu_res(alu_res));
    `endif
endmodule


module alu_dataflow #(parameter XLEN = 32) (
    input op_enum_alu alu_op,
    input logic [XLEN-1:0] alu_a,
    input logic [XLEN-1:0] alu_b,
    output logic [XLEN-1:0] alu_res
);
    always_comb begin
        case (alu_op)
            OP_ALU_ADD: alu_res = alu_a + alu_b;
            OP_ALU_SUB: alu_res = alu_a - alu_b;
            OP_ALU_SLL: alu_res = alu_a << alu_b[4:0];
            OP_ALU_SRL: alu_res = alu_a >> alu_b[4:0];
            OP_ALU_SRA: alu_res = $signed(alu_a) >>> alu_b[4:0];
            OP_ALU_XOR: alu_res = alu_a ^ alu_b;
            OP_ALU_AND: alu_res = alu_a & alu_b;
            OP_ALU_OR:  alu_res = alu_a | alu_b;
            OP_ALU_SLT: alu_res = $signed(alu_a) < $signed(alu_b) ? {XLEN{1'b1}} : {XLEN{1'b0}};
            OP_ALU_SLTU:alu_res = alu_a < alu_b ? {XLEN{1'b1}} : {XLEN{1'b0}};
            default:    alu_res = {XLEN{1'b0}};
        endcase
    end
endmodule
