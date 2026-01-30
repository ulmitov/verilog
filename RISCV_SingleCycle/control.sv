import risc_pkg::*;


module control (
    input logic [6:0] opcode,
    input logic [6:0] funct7,
    input logic [2:0] funct3,

    input logic r_type,
    input logic i_type,
    input logic s_type,
    input logic b_type,
    input logic u_type,
    input logic j_type,

    output op_alu_enum alu_op,
    output logic pc_sel,
    output logic op1_sel,
    output logic op2_sel,
    output op_wr_data_sel rf_wr_data_sel,
    output op_dmem_size dmem_size,
    output logic dmem_req,
    output logic dmem_wr,
    output logic dmem_zero_ex,
    output logic rf_wr_en
);
    logic funct5;
    logic [3:0] funct_r;
    logic [3:0] opcode_i;
    op_alu_enum op_srai;

    assign funct5   = funct7[5];
    assign funct_r  = {funct5, funct3};
    assign opcode_i = {opcode[4], funct3};
    assign dmem_wr  = s_type;
    assign rf_wr_en = ~s_type & ~b_type;
    assign dmem_req = s_type || (rf_wr_data_sel == OP_RF_SEL_MEM);

    always_comb begin
        // defaults
        dmem_zero_ex = 1'b0;
        dmem_size = OP_DMEM_WORD;
        rf_wr_data_sel = OP_RF_SEL_ALU;
        alu_op = OP_ALU_ADD;    // for branching and jumps
        pc_sel = 1'b0;          // 1- alu_res(jump), 0- next_pc
        op1_sel = 1'b0;         // 1- pc, 0- rs1
        op2_sel = ~r_type;      // 1- immediate, 0 -rs2

        if (funct5)
            op_srai = OP_ALU_SRA;
        else
            op_srai = OP_ALU_SRL;

        if (b_type) begin
            op1_sel = 1'b1;     // 1- pc, 0- rs1
        end

        if (j_type) begin
            pc_sel = 1'b1;
            op1_sel = 1'b1;     // 1- pc, 0- rs1
            rf_wr_data_sel = OP_RF_SEL_PC;
        end

        if (s_type) begin
            case (funct3)
                OP_S_TYPE_SB:   dmem_size = OP_DMEM_BYTE;
                OP_S_TYPE_SH:   dmem_size = OP_DMEM_HALF;
                default:        dmem_size = OP_DMEM_WORD;
            endcase
        end

        if (u_type) begin
            case (opcode)
                OPCODE_U_TYPE_LUI: rf_wr_data_sel = OP_RF_SEL_IMM;
                OPCODE_U_TYPE_AUIPC: op1_sel = 1'b1;        // 1- pc, 0- rs1
            endcase
        end

        if (r_type) begin
            //select the alu opcode according to R opcode
            case (funct_r)
                OP_R_TYPE_SUB:  alu_op = OP_ALU_SUB;
                OP_R_TYPE_SLL:  alu_op = OP_ALU_SLL;
                OP_R_TYPE_SLT:  alu_op = OP_ALU_SLT;
                OP_R_TYPE_SLTU: alu_op = OP_ALU_SLTU;
                OP_R_TYPE_XOR:  alu_op = OP_ALU_XOR;
                OP_R_TYPE_SRL:  alu_op = OP_ALU_SRL;
                OP_R_TYPE_SRA:  alu_op = OP_ALU_SRA;
                OP_R_TYPE_OR:   alu_op = OP_ALU_OR;
                OP_R_TYPE_AND:  alu_op = OP_ALU_AND;
                default:        alu_op = OP_ALU_ADD;        // case OP_R_TYPE_ADD
            endcase
        end
        
        if (i_type) begin
            case (opcode_i)
                // Load opearations
                OP_I_TYPE_LB:   {rf_wr_data_sel, dmem_size} = {OP_RF_SEL_MEM, OP_DMEM_BYTE};
                OP_I_TYPE_LH:   {rf_wr_data_sel, dmem_size} = {OP_RF_SEL_MEM, OP_DMEM_HALF};
                OP_I_TYPE_LW:   {rf_wr_data_sel, dmem_size} = {OP_RF_SEL_MEM, OP_DMEM_WORD};
                OP_I_TYPE_LBU:  {dmem_zero_ex, rf_wr_data_sel, dmem_size} = {1'b1, OP_RF_SEL_MEM, OP_DMEM_BYTE};
                OP_I_TYPE_LHU:  {dmem_zero_ex, rf_wr_data_sel, dmem_size} = {1'b1, OP_RF_SEL_MEM, OP_DMEM_HALF};
                // Imm operations
                OP_I_TYPE_SLTI:         alu_op = OP_ALU_SLT;
                OP_I_TYPE_SLTIU:        alu_op = OP_ALU_SLTU;
                OP_I_TYPE_XORI:         alu_op = OP_ALU_XOR;
                OP_I_TYPE_ORI:          alu_op = OP_ALU_OR;
                OP_I_TYPE_ANDI:         alu_op = OP_ALU_AND;
                OP_I_TYPE_SLLI:         alu_op = OP_ALU_SLL;
                OP_I_TYPE_SRLI_SRAI:    alu_op = op_srai;
                default:                alu_op = OP_ALU_ADD; // case OP_I_TYPE_ADDI and OPCODE_I_TYPE_JALR
            endcase

            if (opcode == OPCODE_I_TYPE_JALR) begin
                pc_sel = 1'b1;
                rf_wr_data_sel = OP_RF_SEL_PC;
            end
            //$display("opcode_i=%0h, dmem_req=%0b, rf_wr_data_sel=%0h, OP_RF_SEL_MEM=%0h, dmem_size=%0b", opcode_i, dmem_req, rf_wr_data_sel, OP_RF_SEL_MEM, dmem_size);
        end
    end
endmodule
