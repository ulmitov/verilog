import risc_pkg::*;

`define GATEFLOW 1  //TODO: replace with constss?. if this defined then adder will generate                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         the gateflow objects with delays!!!

module alu (
    input op_alu_enum alu_op,
    input logic [31:0] alu_a,
    input logic [31:0] alu_b,
    output logic [31:0] alu_res
);
    `ifdef GATEFLOW
        reg nadd_sub, right_en, sign;
        reg [31:0] sum, out_sh;
        wire eq, lt, ltu;

        adder #(32) alu_fa_unit (.Nadd_sub(nadd_sub), .X(alu_a), .Y(alu_b), .sum(sum), .carry(), .overflow(), .eq(eq), .lt(lt), .ltu(ltu));
        shift #(32) alu_sh_unit (.right_en(right_en), .sign(sign), .din(alu_a), .shift_n({1'b0, alu_b[4:0]}), .out(out_sh));

        always_comb begin
            case (alu_op)
                OP_ALU_SUB,
                OP_ALU_SLT,
                OP_ALU_SLTU: nadd_sub = 1'b1;
                default: nadd_sub = 1'b0;
            endcase

            case (alu_op)
                OP_ALU_SRL: begin
                    right_en = 1'b1;
                    sign = 1'b0;
                end
                OP_ALU_SRA: begin
                    right_en = 1'b1;
                    sign = 1'b1;
                end
                default: begin
                    // for OP_ALU_SLL and the rest
                    right_en = 1'b0;
                    sign = 1'b0;
                end
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
                OP_ALU_SLT:     alu_res = {32{lt}};
                OP_ALU_SLTU:    alu_res = {32{ltu}};
                default:        alu_res = {32{1'b0}};
            endcase
        end
    `else
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
                OP_ALU_SLT: alu_res = $signed(alu_a) < $signed(alu_b) ? 32'b1 : 32'b0; // TODO; recheck this if iverilog will work
                OP_ALU_SLTU: alu_res = alu_a < alu_b ? 32'b1 : 32'b0;
                default: alu_res = 32'b0;
            endcase
        end
    `endif
endmodule
