import risc_pkg::*;

`define GATEFLOW1 1  //TODO: replace with constss?


module branch_control (
    input logic b_type,
    input logic [2:0] funct3,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,

    output logic branch_taken
);
    `ifdef GATEFLOW1
        wire eq, lt, ltu;
        adder #(32) comparator_unit (.Nadd_sub(1'b1), .X(rs1_data), .Y(rs2_data), .sum(), .carry(), .overflow(), .eq(eq), .lt(lt), .ltu(ltu));
        
        always_comb begin
            if (b_type) begin
                case (funct3)
                    OP_B_TYPE_BEQ: branch_taken = eq;
                    OP_B_TYPE_BNE: branch_taken = ~eq;
                    OP_B_TYPE_BLT: branch_taken = lt;
                    OP_B_TYPE_BGE: branch_taken = ~lt | eq;
                    OP_B_TYPE_BLTU: branch_taken = ltu;
                    OP_B_TYPE_BGEU: branch_taken = ~ltu | eq;
                    default: branch_taken = 1'b0;
                endcase
            end else
                branch_taken = 1'b0;
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
