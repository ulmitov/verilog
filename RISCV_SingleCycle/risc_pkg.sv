/* verilator lint_off UNUSEDPARAM */
`ifndef XLEN
`define XLEN 32
`endif


package risc_pkg;
parameter int RISCV_XLEN = `XLEN;
parameter int IALIGN = 32;
parameter int INST_BASE_ADDRESS = 32'h0;
parameter int DMEM_BASE_ADDRESS = 32'h0;


typedef enum logic [6:0] {
    OPCODE_R_TYPE       = 7'b0110011,   // R-Type. Register to register arithmetic and logic
    OPCODE_S_TYPE       = 7'b0100011,   // S-Type. Store to mem - SB, SH, SW, SD, FSQ
    OPCODE_B_TYPE       = 7'b1100011,   // B-Type. Conditional branches
    OPCODE_U_TYPE_LUI   = 7'b0110111,   // U-Type. LUI and AUIPC - large immediates
    OPCODE_U_TYPE_AUIPC = 7'b0010111,   // U-Type. LUI and AUIPC - large immediates
    OPCODE_U_TYPE_JAL   = 7'b1101111,   // UJ-Type. JAL command  - Unconditional jumps
    OPCODE_I_TYPE_ALU   = 7'b0010011,   // I-Type. Arithmetic with immediate (OP-IMM)
    OPCODE_I_TYPE_LOAD  = 7'b0000011,   // I-Type. Load from mem. Also this mask can be used to detect 32 bit instructions!!!
    OPCODE_I_TYPE_JALR  = 7'b1100111,   // I-Type. JALR - Jump and Link Register
    OPCODE_FLOATP       = 7'b0000111,   // I-Type. Floating pont instructions
    OPCODE_SYSTEM       = 7'b1110011    // I-Type. System instructions - ECALL, EBREAK
} op_enum_base_opcodes /*verilator public*/;


typedef enum logic [2:0] {
    OP_DMEM_BYTE = 3'b000,
    OP_DMEM_HALF = 3'b001,
    OP_DMEM_WORD = 3'b010,      // FLW (OPCODE_FLOATP)
    OP_DMEM_DUBL = 3'b011,      // FLD (OPCODE_FLOATP)
    OP_I_TYPE_LBU = 3'b100,     // FLQ (OPCODE_FLOATP)
    OP_I_TYPE_LHU = 3'b101,
    OP_I_TYPE_LWU = 3'b110,
    OP_DMEM_TRPL = 3'b111       // Custom command, load tripple unsigned. Warning: this code will be probably used by LDU!
} op_enum_dmem_size /*verilator public*/;


typedef enum logic [1:0] {
    OP_RF_SEL_ALU   = 2'b00,
    OP_RF_SEL_MEM   = 2'b01,
    OP_RF_SEL_IMM   = 2'b10,
    OP_RF_SEL_PC    = 2'b11
} op_enum_wr_data_sel;


// B type funct3
typedef enum logic [2:0] {
    OP_B_TYPE_BEQ   = 3'h0,
    OP_B_TYPE_BNE   = 3'h1,
    OP_B_TYPE_BLT   = 3'h4,
    OP_B_TYPE_BGE   = 3'h5,
    OP_B_TYPE_BLTU  = 3'h6,
    OP_B_TYPE_BGEU  = 3'h7
} op_enum_b_type_funct3 /*verilator public*/;


// I type and R type arithmetics
typedef enum logic [2:0] {
    OP_FUNCT3_ADD  = 3'h0,
    OP_FUNCT3_SLL  = 3'h1,
    OP_FUNCT3_SLT  = 3'h2,
    OP_FUNCT3_SLTU = 3'h3,
    OP_FUNCT3_XOR  = 3'h4,
    OP_FUNCT3_SRL  = 3'h5,  // SRLI, SRAI
    OP_FUNCT3_OR   = 3'h6,
    OP_FUNCT3_AND  = 3'h7
} op_enum_funct3 /*verilator public*/;


// Internal ALU opcodes
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
} op_enum_alu /*verilator public*/;
endpackage
/* verilator lint_on UNUSEDPARAM */