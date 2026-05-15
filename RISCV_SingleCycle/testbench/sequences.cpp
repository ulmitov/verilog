#ifndef COMMON_H
#include "common.h"
#endif

extern Logger *logger;
extern Sequencer *sqr;


void push_ref(Transaction *req, char no_zero_cmd = 0) {
    req->test_id = sqr->split_count;
    /*
    req->wr_data &= (1UL << XLEN) - 1;
    req->rd_data &= (1UL << XLEN) - 1;
    req->addr &= (1UL << XLEN) - 1;
    */
    // Log the commands to file, each phase has dedicated file
    if (ref_fifo.empty()) logger->init_log();
    logger->start_log(sqr->split_count);
    fprintf(logger->fptr, "%s", req->str);
    fprintf(logger->fptr, "[%ld]: EXPECT: addr=%08lx data=%08lx\n\n",
            ref_fifo.size(), req->addr, req->wr_data
    );

    ref_fifo.push(*req);
    if (no_zero_cmd) return;
    if (sqr->sqr_fifo.size() / INSTRUCTIONS_LIMIT > sqr->split_count) {
        sqr->push(0);
    }
}


/*
Fill up memory with data value being equal to address value (for test_itype_load_addr_bits)
*/
void seq_prefill_data_memory(const char *mem_fname = "prefill.mem", int word_len = XLEN / 8) {
    remove(mem_fname);
    for (int i = 0; i < DATA_MEMORY_DEPTH / word_len; i++) {
        sqr->put_bytes(mem_fname, i, word_len);
    }
}


// U type
void seq_utype(const char *name, struct isa_utype *cmd) {
    unsigned int decoded_val;
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFFFF;
    decoded_val = cmd->opcode | (cmd->rd << 7) | (cmd->imm << 12);
    sprintf(cmd->str, "%08x\t %s x%d, 0x%0x",
        decoded_val, name, cmd->rd, cmd->imm);
    sqr->push(decoded_val);
}
void seq_lui(struct isa_utype *cmd) {
    unsigned int decoded_val;
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_LUI;
    seq_utype("lui", cmd);
}
void seq_auipc(struct isa_utype *cmd) {
    unsigned int decoded_val;
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_AUIPC;
    seq_utype("auipc", cmd);
}
void seq_jal(struct isa_utype *cmd) {
    unsigned int decoded_val;
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_JAL;
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFFFF;
    decoded_val = cmd->opcode | (cmd->rd << 7);
    decoded_val += ((cmd->imm & 0xFF000) << 12) | ((cmd->imm & 0x800) << 20);
    decoded_val += ((cmd->imm & 0x7FE) << 21) | ((cmd->imm & 0x100000) << 31);
    sprintf(cmd->str, "%08x\t jal x%d, 0x%0x",
        decoded_val, cmd->rd, cmd->imm);
    sqr->push(decoded_val);
}


// S type
void seq_stype(const char *name, struct isa_stype *cmd) {
    unsigned int decoded_val;
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    cmd->imm &= 0xFFF;
    decoded_val = cmd->opcode | ((cmd->imm & 0x1F) << 7) | (cmd->funct3 << 12);
    decoded_val += (cmd->rs1 << 15) | (cmd->rs2 << 20) | ((cmd->imm >> 5) << 25);
    sprintf(cmd->str, "%08x\t %s x%d, 0x%0x(x%d)",
        decoded_val, name, cmd->rs2, cmd->imm, cmd->rs1);
    sqr->push(decoded_val);
}
void seq_sb(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_BYTE;
    seq_stype("sb", cmd);
}
void seq_sh(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_HALF;
    seq_stype("sh", cmd);
}
void seq_st(struct isa_stype *cmd) {            // custom command: store tripple
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_TRPL;
    seq_stype("st", cmd);
}
void seq_sw(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_WORD;
    seq_stype("sw", cmd);
}


// I type
void seq_itype(const char *name, struct isa_itype *cmd, char load_format = 0) {
    unsigned int decoded_val;
    cmd->rs1 &= 0x1F;
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFF;
    decoded_val = cmd->opcode | (cmd->rd << 7)| (cmd->funct3 << 12);
    decoded_val += (cmd->rs1 << 15) | (cmd->imm << 20);
    if (load_format) {
        sprintf(cmd->str, "%08x\t %s x%d, 0x%0x(x%d)",
                decoded_val, name, cmd->rd, cmd->imm, cmd->rs1);
    } else {
        sprintf(cmd->str, "%08x\t %s x%d, x%d, 0x%0x",
                decoded_val, name, cmd->rd, cmd->rs1, cmd->imm);
    }
    sqr->push(decoded_val);
}
// JALR
void seq_jalr(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_JALR;
    cmd->funct3 = 0;
    seq_itype("jalr", cmd);
}

// Load instructions
void seq_lb(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_BYTE;
    seq_itype("lb", cmd, 1);
}
void seq_lh(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_HALF;
    seq_itype("lh", cmd, 1);
}
void seq_lw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_WORD;
    seq_itype("lw", cmd, 1);
}
void seq_lt(struct isa_itype *cmd) {            // custom command: load tripple unsigned
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_TRPL;
    seq_itype("lt", cmd, 1);
}
void seq_lbu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LBU;
    seq_itype("lbu", cmd, 1);
}
void seq_lhu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LHU;
    seq_itype("lhu", cmd, 1);
}
void seq_lwu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LWU;
    seq_itype("lwu", cmd, 1);
}

// Arithmetic instructions
void seq_addi(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    seq_itype("addi", cmd);
}
void seq_slti(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLT;
    seq_itype("slti", cmd);
}
void seq_sltiu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLTU;
    seq_itype("sltiu", cmd);
}
void seq_xori(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_XOR;
    seq_itype("xori", cmd);
}
void seq_ori(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_OR;
    seq_itype("ori", cmd);
}
void seq_andi(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_AND;
    seq_itype("andi", cmd);
}
void seq_slli(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLL;
    cmd->imm = cmd->imm & 0x1F;
    seq_itype("slli", cmd);
}
void seq_srli(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm = cmd->imm & 0x1F;
    seq_itype("srli", cmd);
}
void seq_srai(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm = cmd->imm & 0x1F;
    cmd->imm += 0x400;
    seq_itype("srai", cmd);
}


// B type
void seq_btype(const char *name, struct isa_btype *cmd) {
    unsigned int decoded_val;
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    cmd->imm &= 0xFFF;
    decoded_val = cmd->opcode | ((cmd->imm & 0x800) << 7) | ((cmd->imm & 0x1E) << 8);
    decoded_val += (cmd->funct3 << 12) | (cmd->rs1 << 15) | (cmd->rs2 << 20);
    decoded_val += ((cmd->imm & 0x7E) << 25) | ((cmd->imm & 0x1000) << 31);
    sprintf(cmd->str, "%08x\t %s x%d, 0x%0x(x%d)",
        decoded_val, name, cmd->rs2, cmd->imm, cmd->rs1);
    sqr->push(decoded_val);
}
void seq_beq(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BEQ;
    seq_btype("beq", cmd);
}
void seq_bne(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BNE;
    seq_btype("bne", cmd);
}
void seq_blt(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BLT;
    seq_btype("blt", cmd);
}
void seq_bge(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BGE;
    seq_btype("bge", cmd);
}
void seq_bltu(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BLTU;
    seq_btype("bltu", cmd);
}
void seq_bgeu(struct isa_btype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_B_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_B_TYPE_BGEU;
    seq_btype("bgeu", cmd);
}


// R type
void seq_rtype(const char *name, struct isa_rtype *cmd) {
    unsigned int decoded_val;
    cmd->rd &= 0x1F;
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    decoded_val = cmd->opcode | (cmd->rd << 7) | (cmd->funct3 << 12);
    decoded_val += (cmd->rs1 << 15) | (cmd->rs2 << 20) | (cmd->funct7 << 25);
    sprintf(cmd->str, "%08x\t %s x%d, x%d, x%d",
        decoded_val, name, cmd->rd, cmd->rs1, cmd->rs2);
    sqr->push(decoded_val);
}
void seq_add(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    cmd->funct7 = 0;
    seq_rtype("add", cmd);
}
void seq_sub(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    cmd->funct7 = 0x20;
    seq_rtype("add", cmd);
}
void seq_sll(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLL;
    cmd->funct7 = 0;
    seq_rtype("sll", cmd);
}
void seq_slt(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLT;
    cmd->funct7 = 0;
    seq_rtype("slt", cmd);
}
void seq_sltu(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLTU;
    cmd->funct7 = 0;
    seq_rtype("sltu", cmd);
}
void seq_xor(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_XOR;
    cmd->funct7 = 0;
    seq_rtype("xor", cmd);
}
void seq_or(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_OR;
    cmd->funct7 = 0;
    seq_rtype("or", cmd);
}
void seq_and(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_AND;
    cmd->funct7 = 0;
    seq_rtype("and", cmd);
}
void seq_srl(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->funct7 = 0;
    seq_rtype("srl", cmd);
}
void seq_sra(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_R_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->funct7 = 0x20;
    seq_rtype("sra", cmd);
}
