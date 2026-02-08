`define DEBUG 1
`define GATEFLOW 1


package risc_pkg;

parameter RISCV_XLEN = 32;

typedef enum logic [3:0] {
    OP_ALU_ADD,
    OP_ALU_SUB,
    OP_ALU_SLL,
    OP_ALU_SRL,
    OP_ALU_SRA,
    OP_ALU_XOR,
    OP_ALU_AND,
    OP_ALU_OR,
    OP_ALU_SLT,
    OP_ALU_SLTU
} op_enum_alu;

typedef enum logic [6:0] {
    OPCODE_R_TYPE       = 7'b0110011,   // R-type. Register to register arithmetic and logic
    OPCODE_S_TYPE       = 7'b0100011,   // S-Type. Store operations - write register back to mem
    OPCODE_B_TYPE       = 7'b1100011,   // B-type. Conditional branches
    OPCODE_U_TYPE_LUI   = 7'b0110111,   // U type. LUI and AUIPC - large immediates
    OPCODE_U_TYPE_AUIPC = 7'b0010111,   // U type. LUI and AUIPC - large immediates
    OPCODE_J_TYPE       = 7'b1101111,   // J type. JAL command. Unconditional jumps
    OPCODE_I_TYPE_ALU   = 7'b0010011,   // L-Type. Arithmetic with immediate
    OPCODE_I_TYPE_LOAD  = 7'b0000011,   // L-Type. load instructions
    OPCODE_I_TYPE_JALR  = 7'b1100111,   // L-Type. JALR
    OPCODE_SYSTEM       = 7'b0000111    // System calls (I type)
} op_enum_inst_opcodes;

typedef enum logic [2:0] {
    OP_DMEM_BYTE = 3'b001,
    OP_DMEM_HALF = 3'b010,
    OP_DMEM_TRPL = 3'b011,
    OP_DMEM_WORD = 3'b000
    //OP_DMEM_DUBL
    //OP_DMEM_QUAD
} op_enum_dmem_size;

typedef enum logic [1:0] {
    OP_RF_SEL_ALU = 2'b00,
    OP_RF_SEL_MEM = 2'b01,
    OP_RF_SEL_IMM = 2'b10,
    OP_RF_SEL_PC = 2'b11
} op_enum_wr_data_sel;

// B type inst
typedef enum logic [2:0] {
    OP_B_TYPE_BEQ = 3'h0,
    OP_B_TYPE_BNE = 3'h1,
    OP_B_TYPE_BLT = 3'h4,
    OP_B_TYPE_BGE = 3'h5,
    OP_B_TYPE_BLTU = 3'h6,
    OP_B_TYPE_BGEU = 3'h7
} op_enum_b_type_funct3;

// R type inst
typedef enum logic [3:0] {
    OP_R_TYPE_ADD = 4'h0,
    OP_R_TYPE_SUB = 4'h8,
    OP_R_TYPE_SLL = 4'h1,
    OP_R_TYPE_SLT = 4'h2,
    OP_R_TYPE_SLTU = 4'h3,
    OP_R_TYPE_XOR = 4'h4,
    OP_R_TYPE_SRL = 4'h5,
    OP_R_TYPE_SRA = 4'hD,
    OP_R_TYPE_OR = 4'h6,
    OP_R_TYPE_AND = 4'h7
} op_enum_r_type_funct75_funct3;

// I type inst
typedef enum logic [3:0] {
    OP_I_TYPE_LB = 4'h0,
    OP_I_TYPE_LH = 4'h1,
    OP_I_TYPE_LW = 4'h2,
    OP_I_TYPE_LBU = 4'h4,
    OP_I_TYPE_LHU = 4'h5,
    OP_I_TYPE_ADDI = 4'h8,
    OP_I_TYPE_SLTI = 4'hA,
    OP_I_TYPE_SLTIU = 4'hB,
    OP_I_TYPE_XORI = 4'hC,
    OP_I_TYPE_ORI = 4'hE,
    OP_I_TYPE_ANDI = 4'hF,
    OP_I_TYPE_SLLI = 4'h9,
    OP_I_TYPE_SRLI_SRAI = 4'hD
} op_enum_i_type_funct3;

// S type inst
typedef enum logic [2:0] {
    OP_S_TYPE_SB = 3'h0,
    OP_S_TYPE_SH = 3'h1,
    OP_S_TYPE_SW = 3'h2
} op_enum_s_type_funct3;
endpackage
