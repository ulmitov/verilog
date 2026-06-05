#ifndef COMMON_H
#include "common.h"
#endif
#include "sequencer.cpp"

Sequencer *sqr = new Sequencer();


extern "C" {
    /** Get a transaction from Reference model
    * This function is customized for DPI
    *
    * @param tx: pointer to transaction
    * @return 1 on success, 0 if queue empty or error
    */
    int get_ref(Transaction *tx, int set_str = 1) {
        if (ref_fifo.empty()) return 0;
        if (tx == nullptr) {
            printf("ERROR: Transaction struct is null\n");
            return 0;
        }
        Transaction temp = ref_fifo.front();
        //*tx = temp; For DPI need to set them one by one:
        tx->req = temp.req;
        tx->wr = temp.wr;
        tx->addr = temp.addr;
        tx->wr_data = temp.wr_data;
        tx->rd_data = temp.rd_data;
        tx->test_id = temp.test_id;
        if (set_str) strcpy(tx->str, temp.str); // not copying for DPI
        //printf("EXPECT:  wr: %d  addr: %lx  wr_data: %lx  rd_data: %lx\n", tx->wr, tx->addr, tx->wr_data, tx->rd_data);
        ref_fifo.pop();
        return 1;
    }
}


void push_ref(Transaction *req, char no_zero_cmd = 0) {
    req->test_id = sqr->split_num;
    // masking fields according to XLEN since in transaction it is defined as long:
    if (XLEN < 64) {
        req->wr_data &= (1UL << XLEN) - 1;
        req->rd_data &= (1UL << XLEN) - 1;
    }
    // address can have its own width
    if (DATA_MEMORY_ADDR_WIDTH < 64) {
        req->addr &= (1UL << DATA_MEMORY_ADDR_WIDTH) - 1;
    }

    // each phase commands are logged into separate files
    if (ref_fifo.empty()) logger->init_log();
    logger->start_log(sqr->split_num);
    fprintf(logger->fptr, "%s\n[%ld]: EXPECTED: addr=%08lx data=%08lx\n\n",
            req->str, ref_fifo.size(), req->addr, req->wr_data
    );

    ref_fifo.push(*req);
    if (no_zero_cmd) return;
    if (sqr->size() / INSTRUCTIONS_LIMIT > sqr->split_num) {
        sqr->split();
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
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFFFF;
    cmd->value = cmd->opcode | (cmd->rd << 7) | (cmd->imm << 12);
    sprintf(cmd->str, "%08x\t%s x%d, 0x%0x",
        cmd->value, name, cmd->rd, cmd->imm);
    sqr->push_seq(cmd->value);
}
void seq_lui(struct isa_utype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_LUI;
    seq_utype("lui", cmd);
}
void seq_auipc(struct isa_utype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_AUIPC;
    seq_utype("auipc", cmd);
}
void seq_jal(struct isa_utype *cmd) {
    unsigned int new_imm;
    cmd->opcode = Vriscv_risc_pkg::OPCODE_U_TYPE_JAL;
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFFFF;
    // IMM: 20 | 10:1 | 11 | 19:12 <-- bit 12
    cmd->imm = cmd->imm << 1;
    new_imm = ((cmd->imm & 0xFF000) >> 12) << 12;
    new_imm += ((cmd->imm & 0x800) >> 11) << 20;
    new_imm += ((cmd->imm & 0x7FE) >> 1) << 21;
    new_imm += ((cmd->imm & 0x100000) >> 20) << 31;
    cmd->value = cmd->opcode | (cmd->rd << 7) | new_imm;
    cmd->imm = cmd->imm >> 1;
    sprintf(cmd->str, "%08x\tjal x%d, 0x%0x",
        cmd->value, cmd->rd, cmd->imm);
    sqr->push_seq(cmd->value);
}


// S type
void seq_stype(const char *name, struct isa_stype *cmd) {
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    cmd->imm &= 0xFFF;
    cmd->value = cmd->opcode | ((cmd->imm & 0x1F) << 7) | (cmd->funct3 << 12);
    cmd->value += (cmd->rs1 << 15) | (cmd->rs2 << 20) | ((cmd->imm >> 5) << 25);
    sprintf(cmd->str, "%08x\t%s x%d, 0x%0x(x%d)",
        cmd->value, name, cmd->rs2, cmd->imm, cmd->rs1);
    sqr->push_seq(cmd->value);
}
void seq_sb(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_BYTE;
    cmd->datamask = 0xFF;
    seq_stype("sb", cmd);
}
void seq_sh(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_HALF;
    cmd->datamask = 0xFFFF;
    seq_stype("sh", cmd);
}
void seq_st(struct isa_stype *cmd) {            // custom command: store tripple
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_TRPL;
    cmd->datamask = 0xFFFFFF;
    seq_stype("st", cmd);
}
void seq_sw(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_WORD;
    cmd->datamask = 0xFFFFFFFF;
    seq_stype("sw", cmd);
}
void seq_sd(struct isa_stype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_S_TYPE;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_DUBL;
    cmd->datamask = -1;
    seq_stype("sd", cmd);
}

void set_stype(struct isa_stype *stype, int bits_width = XLEN) {
    switch(bits_width) {
        case 8:
            seq_sb(stype);
            break;
        case 16:
            seq_sh(stype);
            break;
        case 24:
            seq_st(stype);
            break;
        case 32:
            seq_sw(stype);
            break;
        case 64:
            seq_sd(stype);
            break;
        default:
            printf("ERROR: invalid bits_width provided by test\n");
            return;
    }
}



// I type
void seq_itype(const char *name, struct isa_itype *cmd, char bit30 = 0) {
    cmd->rs1 &= 0x1F;
    cmd->rd &= 0x1F;
    cmd->imm &= 0xFFF;
    cmd->value = cmd->opcode | (cmd->rd << 7)| (cmd->funct3 << 12);
    cmd->value += (cmd->rs1 << 15) | (cmd->imm << 20);
    cmd->value += bit30 << 30;
    if (cmd->opcode == Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD) {
        sprintf(cmd->str, "%08x\t%s x%d, 0x%0x(x%d)",
                cmd->value, name, cmd->rd, cmd->imm, cmd->rs1);
    } else if (cmd->opcode == Vriscv_risc_pkg::OPCODE_SYSTEM && cmd->funct3) {
        sprintf(cmd->str, "%08x\t%s x%d, 0x%0x, x%d",
                cmd->value, name, cmd->rd, cmd->imm, cmd->rs1);
    } else if (cmd->opcode == Vriscv_risc_pkg::OPCODE_SYSTEM && !cmd->funct3) {
        sprintf(cmd->str, "%08x\t%s",
                cmd->value, name);
    } else {
        sprintf(cmd->str, "%08x\t%s x%d, x%d, 0x%0x",
                cmd->value, name, cmd->rd, cmd->rs1, cmd->imm);
    }
    sqr->push_seq(cmd->value);
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
    cmd->datamask = 0xFF;
    seq_itype("lb", cmd);
}
void seq_lh(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_HALF;
    cmd->datamask = 0xFFFF;
    seq_itype("lh", cmd);
}
void seq_lw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_WORD;
    cmd->datamask = 0xFFFFFFFF;
    seq_itype("lw", cmd);
}
void seq_ld(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_DUBL;
    cmd->datamask = -1;
    seq_itype("ld", cmd);
}
void seq_lt(struct isa_itype *cmd) {            // custom command: load tripple unsigned
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_DMEM_TRPL;
    cmd->datamask = 0xFFFFFF;
    seq_itype("lt", cmd);
}
void seq_lbu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LBU;
    cmd->datamask = 0xFF;
    seq_itype("lbu", cmd);
}
void seq_lhu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LHU;
    cmd->datamask = 0xFFFF;
    seq_itype("lhu", cmd);
}
void seq_lwu(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_LOAD;
    cmd->funct3 = Vriscv_risc_pkg::OP_I_TYPE_LWU;
    cmd->datamask = 0xFFFFFFFF;
    seq_itype("lwu", cmd);
}

void set_itype_load(struct isa_itype *load, int bits_width, int unsigned_commands = 1) {
    switch(bits_width) {
        case 8:
            if (unsigned_commands) {
                seq_lbu(load);
            } else {
                seq_lb(load);
            }
            break;
        case 16:
            if (unsigned_commands) {
                seq_lhu(load);
            } else {
                seq_lh(load);
            }
            break;
        case 24:
            seq_lt(load);  // this one is unsigned
            break;
        case 32:
            if (unsigned_commands) {
                seq_lwu(load);
            } else {
                seq_lw(load);
            }
            break;
        case 64:
            seq_ld(load);   // signed only, for now now ldu
            break;
        default:
            printf("ERROR: invalid bits_width provided by test\n");
            return;
    }
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
    cmd->imm &= XLEN >= 64 ? 0x3F : 0x1F;
    seq_itype("slli", cmd);
}
void seq_srli(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm &= XLEN >= 64 ? 0x3F : 0x1F;
    seq_itype("srli", cmd);
}
void seq_srai(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_I_TYPE_ALU;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm &= XLEN >= 64 ? 0x3F : 0x1F;
    seq_itype("srai", cmd, 1);
}
void seq_slliw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_ITYPE_IMM_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLL;
    cmd->imm = cmd->imm & 0x1F;
    seq_itype("slliw", cmd);
}
void seq_sraiw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_ITYPE_IMM_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm = cmd->imm & 0x1F;
    seq_itype("sraiw", cmd, 1);
}
void seq_srliw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_ITYPE_IMM_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->imm = cmd->imm & 0x1F;
    seq_itype("srliw", cmd);
}
void seq_addiw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_ITYPE_IMM_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    seq_itype("addiw", cmd);
}

void set_itype_arithmetic(struct isa_itype *itype, int alu_opcode, int op32imm = 0) {
    switch(alu_opcode) {
        case Vriscv_risc_pkg::OP_ALU_ADD:
            if (op32imm) {
                seq_addiw(itype);
            } else {
                seq_addi(itype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SLL:
            if (op32imm) {
                seq_slliw(itype);
            } else {
                seq_slli(itype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SRL:
            if (op32imm) {
                seq_srliw(itype);
            } else {
                seq_srli(itype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SRA:
            if (op32imm) {
                seq_sraiw(itype);
            } else {
                seq_srai(itype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_XOR:
            seq_xori(itype);
            break;
        case Vriscv_risc_pkg::OP_ALU_AND:
            seq_andi(itype);
            break;
        case Vriscv_risc_pkg::OP_ALU_OR:
            seq_ori(itype);
            break;
        case Vriscv_risc_pkg::OP_ALU_SLT:
            seq_slti(itype);
            break;
        case Vriscv_risc_pkg::OP_ALU_SLTU:
            seq_sltiu(itype);
            break;
        default:
            printf("ERROR: invalid ALU opcode provided by test\n");
            return;
    }
}


// B type
void seq_btype(const char *name, struct isa_btype *cmd) {
    unsigned int new_imm;
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    cmd->imm &= 0xFFF;
    cmd->imm = cmd->imm << 1;
    // 4:1 | 11 <-- bit 7
    // 12 | 10:5 <-- bit 25
    new_imm = ((cmd->imm & 0x800) >> 11) << 7;
    new_imm += ((cmd->imm & 0x1E) >> 1) << 8;
    new_imm += ((cmd->imm & 0x7E0) >> 5) << 25;
    new_imm += ((cmd->imm & 0x1000) >> 12) << 31;
    cmd->value = cmd->opcode | (cmd->funct3 << 12) | (cmd->rs1 << 15) | (cmd->rs2 << 20) | new_imm;
    cmd->imm = cmd->imm >> 1;
    sprintf(cmd->str, "%08x\t%s x%d, x%d, 0x%0x",
        cmd->value, name, cmd->rs1, cmd->rs2, cmd->imm);
    sqr->push_seq(cmd->value);
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

void set_btype(struct isa_btype *btype, int btype_opcode) {
    switch(btype_opcode) {
        case Vriscv_risc_pkg::OP_B_TYPE_BEQ:
            seq_beq(btype);
            break;
        case Vriscv_risc_pkg::OP_B_TYPE_BNE:
            seq_bne(btype);
            break;
        case Vriscv_risc_pkg::OP_B_TYPE_BLT:
            seq_blt(btype);
            break;
        case Vriscv_risc_pkg::OP_B_TYPE_BGE:
            seq_bge(btype);
            break;
        case Vriscv_risc_pkg::OP_B_TYPE_BLTU:
            seq_bltu(btype);
            break;
        case Vriscv_risc_pkg::OP_B_TYPE_BGEU:
            seq_bgeu(btype);
            break;
        default:
            printf("ERROR: invalid BTYPE opcode provided by test\n");
            return;
    }
}


// R type
void seq_rtype(const char *name, struct isa_rtype *cmd) {
    cmd->rd &= 0x1F;
    cmd->rs1 &= 0x1F;
    cmd->rs2 &= 0x1F;
    cmd->value = cmd->opcode | (cmd->rd << 7) | (cmd->funct3 << 12);
    cmd->value += (cmd->rs1 << 15) | (cmd->rs2 << 20) | (cmd->funct7 << 25);
    sprintf(cmd->str, "%08x\t%s x%d, x%d, x%d",
        cmd->value, name, cmd->rd, cmd->rs1, cmd->rs2);
    sqr->push_seq(cmd->value);
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
void seq_addw(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_RTYPE_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    cmd->funct7 = 0;
    seq_rtype("addw", cmd);
}
void seq_subw(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_RTYPE_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_ADD;
    cmd->funct7 = 0x20;
    seq_rtype("addw", cmd);
}
void seq_sllw(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_RTYPE_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SLL;
    cmd->funct7 = 0;
    seq_rtype("sllw", cmd);
}
void seq_srlw(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_RTYPE_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->funct7 = 0;
    seq_rtype("srlw", cmd);
}
void seq_sraw(struct isa_rtype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_RTYPE_32;
    cmd->funct3 = Vriscv_risc_pkg::OP_FUNCT3_SRL;
    cmd->funct7 = 0x20;
    seq_rtype("sraw", cmd);
}

void set_rtype(struct isa_rtype *rtype, int alu_opcode, int op32 = 0) {
    switch(alu_opcode) {
        case Vriscv_risc_pkg::OP_ALU_ADD:
            if (op32) {
                seq_addw(rtype);
            } else {
                seq_add(rtype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SUB:
            if (op32) {
                seq_subw(rtype);
            } else {
                seq_sub(rtype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SLL:
            if (op32) {
                seq_sllw(rtype);
            } else {
                seq_sll(rtype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SRL:
            if (op32) {
                seq_srlw(rtype);
            } else {
                seq_srl(rtype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_SRA:
            if (op32) {
                seq_sraw(rtype);
            } else {
                seq_sra(rtype);
            }
            break;
        case Vriscv_risc_pkg::OP_ALU_XOR:
            seq_xor(rtype);
            break;
        case Vriscv_risc_pkg::OP_ALU_AND:
            seq_and(rtype);
            break;
        case Vriscv_risc_pkg::OP_ALU_OR:
            seq_or(rtype);
            break;
        case Vriscv_risc_pkg::OP_ALU_SLT:
            seq_slt(rtype);
            break;
        case Vriscv_risc_pkg::OP_ALU_SLTU:
            seq_sltu(rtype);
            break;
        default:
            printf("ERROR: invalid ALU opcode provided by test\n");
            return;
    }
}


// ZiCSR
void seq_csrrw(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 1;
    seq_itype("csrrw", cmd);
}
void seq_csrrwi(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 5;
    seq_itype("csrrwi", cmd);
}
void seq_csrrs(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 2;
    seq_itype("csrrs", cmd);
}
void seq_csrrsi(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 6;
    seq_itype("csrrsi", cmd);
}
void seq_csrrc(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 3;
    seq_itype("csrrc", cmd);
}
void seq_csrrci(struct isa_itype *cmd) {
    cmd->opcode = Vriscv_risc_pkg::OPCODE_SYSTEM;
    cmd->funct3 = 7;
    seq_itype("csrrci", cmd);
}
void set_csr(struct isa_itype *itype, int funct3) {
    switch(funct3) {
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRW:
            seq_csrrw(itype);
            break;
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRS:
            seq_csrrs(itype);
            break;
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRC:
            seq_csrrc(itype);
            break;
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRWI:
            seq_csrrwi(itype);
            break;
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRSI:
            seq_csrrsi(itype);
            break;
        case Vriscv_risc_pkg::OP_FUNCT3_CSRRCI:
            seq_csrrci(itype);
            break;
        default:
            printf("ERROR: invalid CSR funct3 provided by test\n");
            return;
    }
}
