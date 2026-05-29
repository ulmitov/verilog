import risc_pkg::*;


module branch_control #(parameter XLEN = RISCV_XLEN) (
    input logic b_type,
    input logic [2:0] funct3,
    input logic [XLEN-1:0] rs1_data,
    input logic [XLEN-1:0] rs2_data,
    output logic branch_taken
);
    `ifndef GATE_FLOW_OFF
        wire eq;
        wire lt;
        wire ltu;
        reg b_take;

        adder #(XLEN) branch_comparator (
            .Nadd_sub(1'b1),
            .X(rs1_data),
            .Y(rs2_data),
            .eq(eq),
            .lt(lt),
            .ltu(ltu)
        );

        assign branch_taken = b_type & b_take;
        always_comb begin
            case (funct3)
                OP_B_TYPE_BEQ:  b_take = eq;
                OP_B_TYPE_BNE:  b_take = ~eq;
                OP_B_TYPE_BLT:  b_take = lt;
                OP_B_TYPE_BGE:  b_take = ~lt | eq;
                OP_B_TYPE_BLTU: b_take = ltu;
                OP_B_TYPE_BGEU: b_take = ~ltu | eq;
                default:        b_take = 1'b0;
            endcase
        end
    `else
        always_comb begin
            if (b_type) begin
                case (funct3)
                    OP_B_TYPE_BEQ: branch_taken = rs1_data == rs2_data ? 1'b1 : 1'b0;
                    OP_B_TYPE_BNE: branch_taken = rs1_data != rs2_data ? 1'b1 : 1'b0;
                    OP_B_TYPE_BLT: branch_taken = $signed(rs1_data) < $signed(rs2_data) ? 1'b1 : 1'b0;
                    OP_B_TYPE_BGE: branch_taken = $signed(rs1_data) >= $signed(rs2_data) ? 1'b1 : 1'b0;
                    OP_B_TYPE_BLTU: branch_taken = rs1_data < rs2_data ? 1'b1 : 1'b0;
                    OP_B_TYPE_BGEU: branch_taken = rs1_data >= rs2_data ? 1'b1 : 1'b0;
                    default: branch_taken = 1'b0;
                endcase
            end else
                branch_taken = 1'b0;
        end
    `endif
endmodule
