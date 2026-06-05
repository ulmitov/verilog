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
    input logic c_type,

    output logic pc_sel,
    output logic alua_sel,
    output logic alub_sel,
    output logic rf_wr_en,
    output logic dmem_req,
    output logic dmem_wr,
    output logic dmem_zero_ex,
    output op_enum_dmem_size dmem_size,
    output op_enum_wr_data_sel rf_wr_data_sel,
    output op_enum_alu alu_op
);
    localparam word_len = $clog2(RISCV_XLEN) - 3;
    op_enum_alu op_add;
    op_enum_alu op_sri;
    logic bit_30;
    logic l_type;


    assign bit_30   = funct7[5];
    assign rf_wr_en = ~s_type & ~b_type;
    assign alub_sel = ~r_type;                          // 0- rs2_data, 1- imm
    assign dmem_wr  = s_type;
    assign dmem_req = s_type | l_type;
    assign l_type   = i_type & ~opcode[4] & ~opcode[5]; // l or fl, not arithmetic and not jalr
    assign dmem_zero_ex = l_type & funct3[2];           // I type unsigned load commands only


    // Select RegFile wr_data source
    always_comb begin
        case (opcode)
            OPCODE_U_TYPE_LUI:  rf_wr_data_sel = OP_RF_SEL_IMM;
            OPCODE_U_TYPE_JAL:  rf_wr_data_sel = OP_RF_SEL_PC;
            OPCODE_I_TYPE_JALR: rf_wr_data_sel = OP_RF_SEL_PC;
            OPCODE_I_TYPE_LOAD: rf_wr_data_sel = OP_RF_SEL_MEM;
            OPCODE_I_TYPE_FL:   rf_wr_data_sel = OP_RF_SEL_MEM;
            default:            rf_wr_data_sel = OP_RF_SEL_ALU;
        endcase
    end


    // Branch inst: ALU_A sel: 0- rs1_data, 1- pc
    always_comb begin
        case(opcode)
            OPCODE_B_TYPE,
            OPCODE_U_TYPE_JAL,
            OPCODE_U_TYPE_AUIPC: alua_sel = 1'b1;
            default: alua_sel = 1'b0;
        endcase
    end


    // Select pc increment: 0- next_pc, 1- alu_res(jump)
    always_comb begin
        case(opcode)
            OPCODE_U_TYPE_JAL,
            OPCODE_I_TYPE_JALR: pc_sel = 1'b1;
            default: pc_sel = 1'b0;
        endcase
    end


    // Store and load inst
    always_comb begin
        if (s_type | l_type) begin     // L opcodes can be removed, see above assign dmem_zero_ex
            case (funct3)
                OP_DMEM_BYTE,
                OP_I_TYPE_LBU:  dmem_size = OP_DMEM_BYTE;   // For LBU if opcode[2] is set then it's FLQ cmd
                OP_DMEM_HALF,
                OP_I_TYPE_LHU:  dmem_size = OP_DMEM_HALF;
                OP_DMEM_WORD,
                OP_I_TYPE_LWU:  dmem_size = OP_DMEM_WORD;
                OP_DMEM_DUBL:   dmem_size = OP_DMEM_DUBL;
                OP_DMEM_TRPL:   dmem_size = OP_DMEM_TRPL;
                default:        dmem_size = op_enum_dmem_size'(word_len);
            endcase
        end else
            dmem_size = op_enum_dmem_size'(word_len);   // RISCV_XLEN == 64 ? OP_DMEM_DUBL : OP_DMEM_WORD;
    end


    // I type and R type arithmetics
    always_comb begin
        alu_op = OP_ALU_ADD;        // for branching, jumps, OPCODE_I_TYPE_JALR

        if (bit_30) begin
            op_sri =  OP_ALU_SRA;
            op_add =  OP_ALU_SUB;
        end else begin
            op_sri =  OP_ALU_SRL;
            op_add =  OP_ALU_ADD;
        end

        if (r_type) begin: alu_rs2_operations
            case (funct3)
                OP_FUNCT3_SLT:  alu_op = OP_ALU_SLT;
                OP_FUNCT3_SLTU: alu_op = OP_ALU_SLTU;
                OP_FUNCT3_XOR:  alu_op = OP_ALU_XOR;
                OP_FUNCT3_OR:   alu_op = OP_ALU_OR;
                OP_FUNCT3_AND:  alu_op = OP_ALU_AND;
                OP_FUNCT3_SLL:  alu_op = OP_ALU_SLL;
                OP_FUNCT3_SRL:  alu_op = op_sri;
                default:        alu_op = op_add;
            endcase
        end

        if (c_type) begin: csr_instructions // reusing ALU for csr extension
            case (funct3)
                OP_FUNCT3_CSRRS,
                OP_FUNCT3_CSRRSI:   alu_op = OP_ALU_OR;
                OP_FUNCT3_CSRRC,
                OP_FUNCT3_CSRRCI:   alu_op = OP_ALU_AND;
                default:        alu_op = OP_ALU_ADD;
            endcase
        end 
        else if (i_type & opcode[4]) begin: alu_imm_operations
            case (funct3)
                OP_FUNCT3_SLT: alu_op = OP_ALU_SLT;
                OP_FUNCT3_SLTU: alu_op = OP_ALU_SLTU;
                OP_FUNCT3_XOR:  alu_op = OP_ALU_XOR;
                OP_FUNCT3_OR:   alu_op = OP_ALU_OR;
                OP_FUNCT3_AND:  alu_op = OP_ALU_AND;
                OP_FUNCT3_SLL:  alu_op = OP_ALU_SLL;
                OP_FUNCT3_SRL:  alu_op = op_sri;
                default:        alu_op = OP_ALU_ADD;
            endcase
        end
    end
endmodule
