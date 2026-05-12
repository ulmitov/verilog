#ifndef COMMON_H
#include "common.h"
#endif

extern Sequencer *sqr;


void push_ref(Transaction *req, char no_zero_cmd = 0) {
    req->test_id = sqr->split_count;
    ref_fifo.push(*req);
    if (VERBOSITY) {
        printf("DEBUG [%ld]: EXPECT: addr=%08lx data=%08lx\n",
            ref_fifo.size() - 1, req->addr, req->wr_data
        );
    }
    if (no_zero_cmd) return;
    if (sqr->sqr_fifo.size() / INSTRUCTIONS_LIMIT > sqr->split_count) {
        sqr->push(0);
    }
}


/* Fill up memory with data value being equal to address value */
void seq_prefill_data_memory(const char *mem_fname = "prefill.mem", int word_len = XLEN / 8) {
    remove(mem_fname);
    for (int i = 0; i < DATA_MEMORY_DEPTH / word_len; i++) {
        sqr->put_bytes(mem_fname, i, word_len);
    }
}


void seq_lui(struct isa_lui *cmd) {
    unsigned int decoded_val;
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_LUI;
    decoded_val = cmd->opcode | (cmd->rd << 7) | (cmd->imm << 12);
    sprintf(cmd->str, "%08x\t lui x%d, 0x%0x",
        decoded_val, cmd->rd, cmd->imm);
    if (VERBOSITY) printf("%s\n", cmd->str);
    sqr->push(decoded_val);
}


// ---- S type -----
void seq_stype(const char *name, struct isa_stype *cmd) {
    unsigned int decoded_val;
    decoded_val = cmd->opcode | ((cmd->imm & 0x1F) << 7) | (cmd->funct3 << 12);
    decoded_val += (cmd->rs1 << 15) | (cmd->rs2 << 20) | ((cmd->imm >> 5) << 25);
    sprintf(cmd->str, "%08x\t %s x%d, 0x%0x(x%d)",
        decoded_val, name, cmd->rs2, cmd->imm, cmd->rs1);
    if (VERBOSITY) printf("%s\n", cmd->str);
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


// ---- I type -----
void seq_itype(const char *name, struct isa_itype *cmd, char load_format = 0) {
    unsigned int decoded_val;
    decoded_val = cmd->opcode | (cmd->rd << 7)| (cmd->funct3 << 12);
    decoded_val += (cmd->rs1 << 15) | (cmd->imm << 20);
    if (load_format) {
        sprintf(cmd->str, "%08x\t %s x%d, 0x%0x(x%d)",
                decoded_val, name, cmd->rd, cmd->imm, cmd->rs1);
    } else {
        sprintf(cmd->str, "%08x\t %s x%d, x%d, 0x%0x",
                decoded_val, name, cmd->rd, cmd->rs1, cmd->imm);
    }
    if (VERBOSITY) printf("%s\n", cmd->str);
    sqr->push(decoded_val);
}
// Load instructions
void seq_lb(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LB;        // TODO: can change to BYTE ?
    seq_itype("lb", cmd, 1);
}
void seq_lh(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LH;
    seq_itype("lh", cmd, 1);
}
void seq_lw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LW;
    seq_itype("lw", cmd, 1);
}
void seq_lt(struct isa_itype *cmd) {            // custom command: load tripple
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
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_ADDI;
    seq_itype("addi", cmd);
}
