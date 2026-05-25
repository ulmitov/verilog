#ifndef COMMON_H
#include "common.h"
#endif
#include "sequences.cpp"

struct Transaction ref_req;
struct Transaction drv_req;
// TODO: for 64 bit need to add loading upper 32 bits to lui in all tests


void generate_bit_patterns(
    long *arr,
    int bits_width = XLEN,
    int length = SEQUENCES_NUM
) {
    long mask_ff = bits_width == 64 ? -1 : (1ULL << bits_width) - 1;
    // high to low and low to high
    *arr++ = 0;
    *arr++ = mask_ff;
    *arr++ = 0;
    *arr++ = mask_ff;
    length -= 4;

    // some patterns
    *arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
    *arr++ = 0x5555555555555555 & mask_ff;
    //*arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
    *arr++ = 0xDBDBDBDBDBDBDBDB & mask_ff;
    *arr++ = 0xB6B6B6B6B6B6B6B6 & mask_ff;
    //*arr++ = 0x6D6D6D6D6D6D6D6D & mask_ff;
    length -= 4;

    // fill with random values up to requested array length
    while (length > bits_width) {
        if (bits_width > 32) {
            *arr++ = mask_ff & ((long)rand() | ((long)rand() << 32));
        } else {
            *arr++ = mask_ff & rand();
        }
        length--;
    }

    // toggle bit by bit
    for (int i = 0; i < length; i++) *arr++ = 1 << i;
}


/** Sign extend
 *
 * @param data: the data to be extended
 * @param bits_num: bits size of the field that is extended
 * @return sign-extended long data
 */
long sign_extend(long data, int bits_num = 12) {
    bits_num = 64 - bits_num;   // 64 is for long data type
    data = data << bits_num;
    data = data >> bits_num;
    return data;
}


/** Get the value based on lui and addi commands
 *
 * @param lui_base_val: lui imm
 * @param imm_val: addi imm
 * @return long: sum of both sign-extended to 64 bits
 */
long int get_lui_base_imm_value(long int lui_base_val, long int imm_val) {
    return sign_extend(lui_base_val << 12, 32) + sign_extend(imm_val);
}


/* Verify commands with zero values and check that Reg[x0] is not overriden by LUI */
void generate_stype_acceptance() {
    struct isa_utype lui_base;
    struct isa_stype stype;
    printf("INFO: Generating transactions: LUI and Stype commands with zero values\n");

    for (int block_size = 3; block_size < 7; block_size++) {
        if (XLEN < 64 && block_size > 5) break;
        // lui rd will hold the base address for stype
        lui_base.rd = 0;
        lui_base.imm = rand();
        seq_lui(&lui_base);

        // Stype: copy value from [rs2] into mem[[rs1]+imm]
        stype.imm = 0;
        stype.rs1 = 0;
        stype.rs2 = 0;
        set_stype(&stype, 1 << block_size);

        // Reference transaction
        ref_req.wr = 1;
        ref_req.addr = 0;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        sprintf(ref_req.str, "%s\n%s\n", lui_base.str, stype.str);
        push_ref(&ref_req);
    }
}


/* Verify lui and stype produce correct address bits */
void generate_stype_imm_lui_imm(int bits_width) {
    struct isa_utype lui_base;
    struct isa_stype stype;
    long patterns[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Stype rs1 imm and lui imm fields verification\n", bits_width);
    generate_bit_patterns(&patterns[0]);

    for (int i = 0; i < SEQUENCES_NUM; i++) {
        // lui rd will hold the base address for stype
        lui_base.rd = REGFILE_A0;
        lui_base.imm = patterns[i] >> 12;
        seq_lui(&lui_base);

        // Stype: copy value from [rs2] into mem[[rs1]+imm]
        stype.imm = patterns[i];
        stype.rs1 = lui_base.rd;
        stype.rs2 = 0;
        set_stype(&stype, bits_width);

        // Reference transaction: expect addr to be: lui_base.imm << 12 + (signed)stype.imm
        ref_req.wr = 1;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        ref_req.addr = (lui_base.imm << 12) + sign_extend(stype.imm);
        sprintf(ref_req.str, "%s\n%s\n", lui_base.str, stype.str);
        push_ref(&ref_req);
    }
}


/* Verify lui, addi and stype produce correct data bits */
void generate_stype_data(int bits_width) {
    struct isa_utype lui_base;
    struct isa_utype lui_data;
    struct isa_itype addi;
    struct isa_stype stype;
    long patterns[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Stype data verification\n", bits_width);
    generate_bit_patterns(&patterns[0]);

    // TODO: if the loops get bigger then move it inside the loops
    lui_base.rd = REGFILE_A0;
    lui_base.imm = DATA_MEMORY_BASE_ADDR >> 12;
    seq_lui(&lui_base);

    for (int dreg = 1; dreg < MAX_REG; dreg++) {
        if (dreg == REGFILE_A0) continue;

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set the upper imm value
            lui_data.rd = dreg;
            lui_data.imm = patterns[i] >> 12;
            seq_lui(&lui_data);

            // set rd = rs1 + imm
            addi.rd = dreg;
            addi.rs1 = dreg;
            addi.imm = patterns[i];
            seq_addi(&addi);

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = (patterns[i] / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
            stype.rs1 = lui_base.rd;
            stype.rs2 = dreg;
            set_stype(&stype, bits_width);

            // Reference transaction: expect wr_data to be: lui_data.imm << 12 + (signed)addi.imm & (width mask)
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.wr_data = get_lui_base_imm_value(lui_data.imm, addi.imm) & stype.datamask;
            ref_req.addr = (lui_base.imm << 12) + sign_extend(stype.imm);
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n",
                lui_base.str, lui_data.str, addi.str, stype.str);
            push_ref(&ref_req);
        }
    }
}


/* Verify commands with zero values */
void generate_itype_load_acceptance() {
    struct isa_utype lui_base;
    struct isa_itype load;
    struct isa_itype addi;

    printf("INFO: Generating transactions: Itype load command acceptance\n");

    for (int block_size = 3; block_size < 7; block_size++) {
        if (XLEN < 64 && block_size > 5) break;
        // set into reg the address for load
        lui_base.rd = 0;
        lui_base.imm = rand();
        seq_lui(&lui_base);

        addi.rd = 0;
        addi.rs1 = 0;
        addi.imm = rand();
        seq_addi(&addi);

        load.rd = 0;
        load.rs1 = 0;
        load.imm = 0;
        set_itype_load(&load, 1 << block_size, 0);

        // Reference transaction
        ref_req.wr = 0;
        ref_req.addr = 0;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        sprintf(ref_req.str, "%s\n%s\n", lui_base.str, load.str);
        push_ref(&ref_req);
    }
}


/* Verify load commands produce correct address bits */
void generate_itype_load_address(int bits_width, char unsigned_commands = 0) {
    struct isa_utype lui_base;
    struct isa_itype load;
    struct isa_stype stype;
    long patterns_12[SEQUENCES_NUM];
    long patterns_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Itype load command addr verification\n", bits_width);
    generate_bit_patterns(&patterns_12[0], 12);
    generate_bit_patterns(&patterns_20[0], 20);

    for (int dreg = 1; dreg < MAX_REG; dreg++) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set into reg the address for load
            lui_base.rd = dreg;
            lui_base.imm = patterns_20[i];
            seq_lui(&lui_base);

            // Load Itype: copy value from mem[[rs1]+imm] into reg[rd]
            load.rd = dreg < 31 ? dreg + 1 : 0;
            load.rs1 = dreg;
            load.imm = patterns_12[i];
            set_itype_load(&load, bits_width, unsigned_commands);

            // Reference transaction (load reaction)
            ref_req.wr = 0;
            ref_req.wr_data = 0;
            ref_req.addr = (lui_base.imm << 12) + sign_extend(load.imm);
            // precondition: data memory was prefilled with each address holding 4 bytes equal to the address value!
            if (ref_req.addr >= DATA_MEMORY_BASE_ADDR && ref_req.addr < DATA_MEMORY_LAST_ADDR) {
                ref_req.rd_data = ref_req.addr & load.datamask;
            } else {
                ref_req.rd_data = 0;  // TODO Drive value?
            }
            sprintf(ref_req.str, "%s\n%s\n", lui_base.str, load.str);
            push_ref(&ref_req, 1);

            // Verify data was loaded into the reg Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = load.imm;
            stype.rs1 = load.rs1;
            stype.rs2 = load.rd;
            set_stype(&stype, bits_width);

            // Reference transaction
            ref_req.wr = 1;
            if (!load.rd) {
                ref_req.wr_data = 0;
            } else if (unsigned_commands) {
                ref_req.wr_data = ref_req.rd_data & stype.datamask;
            } else {
                ref_req.wr_data = sign_extend(ref_req.rd_data & stype.datamask, bits_width);
            }
            ref_req.rd_data = 0;
            // ref_req.addr remains same
            sprintf(ref_req.str, "%s\n%s\n%s\n", lui_base.str, load.str, stype.str);
            push_ref(&ref_req);
        }
    }
}


/* Verify load commands produce correct data bits */
void generate_itype_load_data(int bits_width, char unsigned_commands = 0) {
    struct isa_utype lui_base;
    struct isa_utype lui_data;
    struct isa_utype lui_base_stype;
    struct isa_itype addi;
    struct isa_itype load;
    struct isa_stype stype;
    long patterns[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Itype load command data verification\n", bits_width);
    generate_bit_patterns(&patterns[0], 12);

    for (int dreg = 1; dreg < MAX_REG; dreg++) {
        if (dreg == REGFILE_A0 || dreg == REGFILE_A1) continue;

        for (int i = 0; i < SEQUENCES_NUM; i++) {

            // set base address to read outside of data memory
            // this address should be unique as it will be used by driver to drive rd data
            lui_base.rd = REGFILE_A1;
            lui_base.imm = 0xA0000 + rand() % 0x60000; // TODO: set random vals or stimulus?
            seq_lui(&lui_base);

            // fill data destination reg high bits
            lui_data.rd = dreg;
            lui_data.imm = rand();
            seq_lui(&lui_data);

            // fill data destination reg lower bits
            addi.rd = dreg;
            addi.rs1 = dreg;
            addi.imm = rand();
            seq_addi(&addi);

            // Load Itype: copy value from mem[[rs1]+imm] into reg[rd]
            load.rd = dreg;
            load.rs1 = lui_base.rd;
            load.imm = patterns[i]; // / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
            set_itype_load(&load, bits_width, unsigned_commands);

            // Reference transaction (load + drive reaction)
            ref_req.wr = 0;
            ref_req.wr_data = 0;
            ref_req.addr = (lui_base.imm << 12) + sign_extend(load.imm);
            ref_req.rd_data = rand() & load.datamask;
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str);
            push_ref(&ref_req, 1);

            // driver to set rd_data with random data
            drv_req.wr = 0;
            drv_req.addr = ref_req.addr;
            // TODO: for external memory, add block size logic in load commands, then remove the data mask from here:
            // also apply stimulus here, need to verify high to low, etc...
            drv_req.rd_data = ref_req.rd_data;
            drv_req.test_id = sqr->split_num;
            sprintf(drv_req.str, "%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str);
            drv_fifo.push(drv_req);
            fprintf(logger->fptr, "GEN: pushed to driver transaction with addr %0lx, rd_data %0lx\n\n",
                    drv_req.addr, drv_req.rd_data);

            // Verify data was loaded correctly into destination reg
            // Store data from destination reg to some random memory:
            // set base address to write inside of data memory
            lui_base_stype.rd = REGFILE_A0;
            lui_base_stype.imm = DATA_MEMORY_BASE_ADDR << 12;
            seq_lui(&lui_base_stype);

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = (rand() / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
            stype.rs1 = lui_base_stype.rd;
            stype.rs2 = dreg;
            set_stype(&stype);

            // Reference transaction
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.addr = (lui_base_stype.imm << 12) + sign_extend(stype.imm);
            if (!dreg) {
                ref_req.wr_data = 0;
            } else if (unsigned_commands) {
                ref_req.wr_data = drv_req.rd_data;
            } else {
                ref_req.wr_data = sign_extend(drv_req.rd_data, bits_width);
            }
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str, lui_base_stype.str, stype.str);
            push_ref(&ref_req);
        }
    }
}


/* Verify itype commands produce correct arithmetic results */
void generate_itype_arithmetic(int opcode, int op32 = 0) {
    struct isa_utype lui_base;
    struct isa_stype stype;
    struct isa_itype itype;
    struct isa_itype addi;
    long patterns[SEQUENCES_NUM];

    printf("INFO: Generating transactions: Itype arithmetic command with opcode %d\n", opcode);
    generate_bit_patterns(&patterns[0], 12);

    // first loop running with zeros, i.e acceptance test!
    for (int sreg = 0; sreg < MAX_REG; sreg++) {
        for (int dreg = 0; dreg < MAX_REG; dreg++) {
            for (int i = 0; i < SEQUENCES_NUM; i++) {
                if (dreg == 0 && i == 4) break; // for x0 4 first sequences is enough

                // lui rd will hold the upper bits for itype.rs1
                lui_base.rd = sreg;
                lui_base.imm = rand();
                seq_lui(&lui_base);

                // fill itype.rs1 lower bits
                addi.rd = sreg;
                addi.rs1 = sreg;
                addi.imm = rand();
                seq_addi(&addi);

                // rd = rs1 + imm
                itype.rd = dreg;
                itype.rs1 = sreg;
                itype.imm = patterns[i];
                set_itype_arithmetic(&itype, opcode, op32);

                // Stype: copy value from [rs2] into mem[[rs1]+imm]
                stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
                stype.rs1 = 0;              // x0 is always 0 so in this test always saving to mem range 0 +/- 4096
                stype.rs2 = itype.rd;
                set_stype(&stype);

                // Reference transaction
                ref_req.wr = 1;
                ref_req.rd_data = 0;
                ref_req.addr = sign_extend(stype.imm);
                ref_req.wr_data = sreg ? get_lui_base_imm_value(lui_base.imm, addi.imm) : 0;
                sprintf(ref_req.str, "%s\n%s\n%s\n%s\n", lui_base.str, addi.str, itype.str, stype.str);

                switch(opcode) {
                    case Vriscv_risc_pkg::OP_ALU_ADD:
                        ref_req.wr_data += sign_extend(itype.imm);
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLL:
                        ref_req.wr_data = ref_req.wr_data << itype.imm;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SRL:
                        // masking because wr_data is long and shift right must push zeros from the left
                        ref_req.wr_data = (unsigned long)(ref_req.wr_data & stype.datamask) >> itype.imm;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SRA:
                        ref_req.wr_data = ref_req.wr_data >> itype.imm;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_XOR:
                        ref_req.wr_data ^= sign_extend(itype.imm);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_AND:
                        ref_req.wr_data &= sign_extend(itype.imm);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_OR:
                        ref_req.wr_data |= sign_extend(itype.imm);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLT:
                        ref_req.wr_data = ref_req.wr_data < sign_extend(itype.imm);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLTU:
                        ref_req.wr_data = (unsigned long)ref_req.wr_data < (unsigned long)sign_extend(itype.imm);
                        break;
                    default:
                        printf("ERROR: invalid ALU opcode provided by test\n");
                        return;
                }
                if (!dreg) ref_req.wr_data = 0;
                push_ref(&ref_req);
            }
        }
    }
}




/* Verify rtype commands produce correct arithmetic results */
void generate_rtype(int opcode, int op32 = 0) {
    struct isa_utype lui_rs1;
    struct isa_utype lui_rs2;
    struct isa_stype stype;
    struct isa_rtype rtype;
    struct isa_itype addi_rs1;
    struct isa_itype addi_rs2;
    long patterns_12_rs1[SEQUENCES_NUM];
    long patterns_20_rs1[SEQUENCES_NUM];
    long patterns_12_rs2[SEQUENCES_NUM];
    long patterns_20_rs2[SEQUENCES_NUM];
    long rs1;
    long rs2;
    int shift_amount;

    printf("INFO: Generating transactions: Rtype command with opcode %d\n", opcode);
    generate_bit_patterns(&patterns_12_rs1[0], 12);
    generate_bit_patterns(&patterns_20_rs1[0], 20);
    generate_bit_patterns(&patterns_12_rs2[0], 12);
    generate_bit_patterns(&patterns_20_rs2[0], 20);

    // first loop running with zeros, i.e acceptance test!
    for (int reg_rs1 = 0; reg_rs1 < MAX_REG; reg_rs1++) {
        for (int reg_rs2 = 0; reg_rs2 < MAX_REG; reg_rs2++) {

            for (int i = 0; i < SEQUENCES_NUM; i++) {
                if ((!reg_rs1 || !reg_rs2) && i == 6) break;    // 6 sequences is enough
                if ((reg_rs1 == reg_rs2) && i == 6) break;

                // lui rd will hold the upper bits for itype.rs1
                lui_rs1.rd = reg_rs1;
                lui_rs1.imm = patterns_20_rs1[i];
                seq_lui(&lui_rs1);

                // fill rtype.rs1 lower bits
                addi_rs1.rd = reg_rs1;
                addi_rs1.rs1 = reg_rs1;
                addi_rs1.imm = patterns_12_rs1[i];
                seq_addi(&addi_rs1);

                // lui rd will hold the upper bits for rtype.rs1
                lui_rs2.rd = reg_rs2;
                lui_rs2.imm = patterns_20_rs2[i];
                seq_lui(&lui_rs2);

                // fill rtype.rs1 lower bits
                addi_rs2.rd = reg_rs2;
                addi_rs2.rs1 = reg_rs2;
                addi_rs2.imm = patterns_12_rs2[i];
                seq_addi(&addi_rs2);

                // rd = rs1 + rs2
                rtype.rd = i % 32;
                rtype.rs1 = reg_rs1;
                rtype.rs2 = reg_rs2;
                set_rtype(&rtype, opcode, op32);

                // Stype: copy value from [rs2] into mem[[rs1]+imm]
                stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
                stype.rs1 = 0;              // x0 is always 0 so in this test always saving to mem range 0 +/- 4096
                stype.rs2 = rtype.rd;
                set_stype(&stype);

                rs1 = reg_rs1 ? get_lui_base_imm_value(lui_rs1.imm, addi_rs1.imm) : 0;
                rs2 = reg_rs2 ? get_lui_base_imm_value(lui_rs2.imm, addi_rs2.imm) : 0;
                if (reg_rs1 && reg_rs1 == reg_rs2) rs1 = rs2;
                shift_amount = XLEN >= 64 ? rs2 & 0x3F : rs2 & 0x1F;

                switch(opcode) {
                    case Vriscv_risc_pkg::OP_ALU_ADD:
                        ref_req.wr_data = rs1 + rs2;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SUB:
                        ref_req.wr_data = rs1 - rs2;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLL:
                        ref_req.wr_data = rs1 << shift_amount;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SRL:
                        ref_req.wr_data = rs1 << shift_amount;
                        // masking because rs1 is long and shift right must push zeros from the left
                        ref_req.wr_data = (unsigned long)(rs1 & stype.datamask) >> shift_amount;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SRA:
                        ref_req.wr_data = rs1 >> shift_amount;
                        if (op32) ref_req.wr_data = sign_extend(ref_req.wr_data, 32);
                        break;
                    case Vriscv_risc_pkg::OP_ALU_XOR:
                        ref_req.wr_data = rs1 ^ rs2;
                        break;
                    case Vriscv_risc_pkg::OP_ALU_AND:
                        ref_req.wr_data = rs1 & rs2;
                        break;
                    case Vriscv_risc_pkg::OP_ALU_OR:
                        ref_req.wr_data = rs1 | rs2;
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLT:
                        ref_req.wr_data = rs1 < rs2;
                        break;
                    case Vriscv_risc_pkg::OP_ALU_SLTU:
                        ref_req.wr_data = (unsigned long)rs1 < (unsigned long)rs2;
                        break;
                    default:
                        printf("ERROR: invalid ALU opcode provided by test\n");
                        return;
                }
                // Reference transaction
                ref_req.wr = 1;
                ref_req.rd_data = 0;
                ref_req.addr = sign_extend(stype.imm);
                if (!rtype.rd) ref_req.wr_data = 0;
                sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s\n%s\n",
                        lui_rs1.str, addi_rs1.str, lui_rs2.str,
                        addi_rs2.str, rtype.str, stype.str);
                push_ref(&ref_req);
            }
        }
    }
}


/* Verify AUIPC */
void generate_auipc() {
    struct isa_stype stype;
    struct isa_utype auipc;
    //unsigned long int patterns_12[SEQUENCES_NUM];
    long patterns[SEQUENCES_NUM];
    unsigned long pc = 0;

    printf("INFO: Generating transactions: AUIPC verification\n");
    //generate_bit_patterns(&patterns_12[0], 12);
    generate_bit_patterns(&patterns[0], 20);

    for (int dreg = 0; dreg < MAX_REG; dreg += 1) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            if (!dreg && i == 4) break; // 4 sequences is enough

            // rd = pc + imm << 12
            auipc.rd = dreg;
            auipc.imm = patterns[i];
            seq_auipc(&auipc);

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.rs1 = 0;
            stype.rs2 = dreg;
            stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
            set_stype(&stype);

            // Reference transaction
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.wr_data = dreg ? pc * 4 + sign_extend(auipc.imm << 12, 32) : 0;
            ref_req.addr = sign_extend(stype.imm);
            sprintf(ref_req.str, "%s\n%s\n", auipc.str, stype.str);
            push_ref(&ref_req);

            pc += 2;
            if (pc >= INSTRUCTIONS_LIMIT) {
                pc = 0;
            }
        }
    }
}


/* Verify JAL jumps forward */
void generate_jal_forward() {
    struct isa_utype jal;
    struct isa_stype stype;
    struct isa_stype dummy_stype;
    long patterns[SEQUENCES_NUM];
    unsigned long pc = 0;
    long max_jump = INSTRUCTIONS_LIMIT * 4;
    int next_stimulus;
    int fill_up;
    int offset;
    int n;

    printf("INFO: Generating transactions: JAL positive jumps verification\n");
    generate_bit_patterns(&patterns[0], 20);

    for (int dreg = 0; dreg < MAX_REG; dreg++) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            if (!dreg && i == 4) break; // 4 sequences is enough

            // positive numbers 4 bytes aligned
            offset = (patterns[i] % max_jump) & 0x7FFFC;
            if (!offset) offset = 4;

            // TODO: check also 2 bytes after adding C extension
            // jump by only positive jumps, 4 bytes aligned, not equal to zero:
            // TODO: imm 0 will get into an infinite loop, verify 0 with csr's
            // rd = pc + 4; PC += imm
            jal.rd = dreg;
            jal.imm = offset >> 1;
            seq_jal(&jal);

            // fill up with dummy stype to be sure those commands were jumped over
            fill_up = (offset / 4) - 1;
            for (n = 0; n < fill_up; n++) {
                set_stype(&dummy_stype);
            }

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
            stype.rs1 = 0;
            stype.rs2 = dreg;
            set_stype(&stype);

            // Reference transaction
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.wr_data = dreg ? pc + 4 : 0;
            ref_req.addr = sign_extend(stype.imm);
            sprintf(ref_req.str, "%s\n%s\njump %lx->%lx\n", jal.str, stype.str, pc, pc + offset);
            push_ref(&ref_req, 1);

            if (VERBOSITY) {
                printf("JAL.IMM=0x%x, max_jump=%ld, fill_up=%d, pc=0x%lx\n", jal.imm, max_jump, fill_up, pc);
            }
            pc += offset + 4;

            // check if need to split mem file
            max_jump = INSTRUCTIONS_LIMIT * 4 - pc;
            next_stimulus = 0;
            if (i < SEQUENCES_NUM - 1 && max_jump) {
                next_stimulus = (patterns[i+1] % max_jump) & 0x7FFFC;
                if (next_stimulus < 8) next_stimulus = 8;
            }
            if (!max_jump || pc + next_stimulus >= INSTRUCTIONS_LIMIT * 4) {
                sqr->split();
                pc = 0;
                max_jump = INSTRUCTIONS_LIMIT * 4;
            }
        }
    }
}


/** Verify JAL jumps backward:
 * jump forward by imm, then jump backward by imm and execute store
 */
void generate_jal_backward() {
    struct isa_utype jal_tested;
    struct isa_utype jal_before;
    struct isa_utype jal_after;
    struct isa_stype stype;
    struct isa_stype dummy_stype;
    long patterns[SEQUENCES_NUM];
    unsigned long pc_stype = 0;
    unsigned long pc = 0;
    long max_jump = INSTRUCTIONS_LIMIT * 4;
    int next_stimulus;
    int fill_up;
    int offset;
    int n;

    printf("INFO: Generating transactions: JAL negative jumps verification\n");
    generate_bit_patterns(&patterns[0], 20);

    for (int dreg = 0; dreg < MAX_REG; dreg++) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            if (!dreg && i == 4) break; // 4 sequences is enough

            offset = (patterns[i] % max_jump) & 0x7FFFC; // 4 bytes aligned
            if (offset < 8) offset = 8;     // min jump backward is 2 commands: stype + jal_after

            // jump forward to the tested command (offset + jal_tested cmd)
            jal_before.rd = 0;
            jal_before.imm = (offset + 4) >> 1;
            seq_jal(&jal_before);

            // verify rd is correct
            stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
            stype.rs1 = 0;
            stype.rs2 = dreg;
            set_stype(&stype);  // Stype: copy value from [rs2] into mem[[rs1]+imm]

            // jump again to right after the tested jal to proceed with test
            jal_after.imm = offset >> 1;
            seq_jal(&jal_after);

            // fill up with dummy stype to be sure those commands were jumped over
            fill_up = (offset / 4) - 2;
            for (n = 0; n < fill_up; n++) {
                set_stype(&dummy_stype);
            }

            // the tested jump: jump backwards to where the correct stype was placed
            jal_tested.rd = dreg;
            jal_tested.imm = 0 - (offset >> 1);
            seq_jal(&jal_tested);

            pc_stype = pc + 4;  // pc + jal_before
            pc += offset + 8;   // pc + offset + jal_before + default pc incr

            // Reference transaction: JAL: rd = pc + 4; PC += imm
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.wr_data = dreg ? pc : 0;
            ref_req.addr = sign_extend(stype.imm);
            sprintf(ref_req.str, "%s\n%s\n%s\n%s (%d times)\n%s\njump %lx->%lx\n",
                jal_before.str, stype.str, jal_after.str, dummy_stype.str, fill_up, jal_tested.str, pc - 4, pc_stype);
            push_ref(&ref_req, 1);

            if (VERBOSITY) {
                printf("NEGATIVE JAL=%x offset=0x%x, PC=0x%lx  max_jump=%ld\n",
                    jal_tested.imm, offset, pc, max_jump);
            }
            
            // check if need to split mem file
            max_jump = INSTRUCTIONS_LIMIT * 4 - pc;
            next_stimulus = 0;
            if (i < SEQUENCES_NUM - 1 && max_jump) {
                next_stimulus = (patterns[i+1] % max_jump) & 0x7FFFC;
                if (next_stimulus < 8) next_stimulus = 8;
            }
            if (!max_jump || pc + next_stimulus >= INSTRUCTIONS_LIMIT * 4) {
                sqr->split();
                pc = 0;
                max_jump = INSTRUCTIONS_LIMIT * 4;
            }
        }
    }
}



/* Verify Btype does not jump
 * This will verify the brunch comparator unit for returning correct results
 */
void generate_btype_no_jump(int btype_opcode) {
    struct isa_btype btype;
    struct isa_stype stype;
    struct isa_utype lui;
    struct isa_itype addi_rs1;
    struct isa_itype addi_rs2;
    struct isa_utype lui_help;
    struct isa_itype addi_help;
    struct isa_itype slli_help;
    struct isa_rtype rhelp;
    struct isa_rtype srl_help;
    long patterns[SEQUENCES_NUM];
    long pattern;
    long rs1;
    long rs2;
    int reg_helper;

    printf("INFO: Generating transactions: Btype opcode %d no jump verification\n", btype_opcode);
    generate_bit_patterns(&patterns[0], XLEN);

    for (int reg_rs1 = 0; reg_rs1 < MAX_REG; reg_rs1++) {
        for (int reg_rs2 = 0; reg_rs2 < MAX_REG; reg_rs2++) {
            for (int i = 0; i < SEQUENCES_NUM; i++) {
                if ( (!reg_rs1 || !reg_rs2) && i == 4 ) break; // 4 sequences is enough

                pattern = patterns[i];

                switch(btype_opcode) {
                    case Vriscv_risc_pkg::OP_B_TYPE_BEQ:
                        if (reg_rs1 == reg_rs2) continue;
                        if (!reg_rs2 && !pattern) continue;
                        addi_rs2.imm = 1 + rand();
                        break;
                    case Vriscv_risc_pkg::OP_B_TYPE_BNE:
                        // rs2 should be equal
                        if (!reg_rs2 && pattern) continue;
                        addi_rs2.imm = 0;
                        break;
                    case Vriscv_risc_pkg::OP_B_TYPE_BLT:
                        // signed rs2 must be less or equal
                        if (!reg_rs2 && pattern <= 0) continue;
                        addi_rs2.imm = rand() | 0x800;
                        break;
                    case Vriscv_risc_pkg::OP_B_TYPE_BGE:
                        // signed rs2 must be bigger
                        if (reg_rs1 == reg_rs2) continue;
                        if (!reg_rs2 && pattern >= 0) continue;
                        if (pattern <= 0) continue;
                        addi_rs2.imm = 1 + rand() & 0x7FF;
                        break;
                    case Vriscv_risc_pkg::OP_B_TYPE_BLTU:
                        // unsigned rs2 must be less or equal
                        if (!reg_rs1) continue;
                        if (pattern >= 0) continue;
                        addi_rs2.imm = rand() | 0x800;
                        break;
                    case Vriscv_risc_pkg::OP_B_TYPE_BGEU:
                        // unsigned rs2 must be bigger
                        if (reg_rs1 == reg_rs2) continue;
                        if (!reg_rs2) continue;
                        if (pattern <= 0) continue;
                        addi_rs2.imm = 1 + rand() & 0x7FF;
                        break;
                    default:
                        printf("ERROR: invalid BTYPE opcode provided by test\n");
                        return;
                }

                lui.rd = reg_rs1;
                lui.imm = (pattern - sign_extend(pattern & 0xFFF)) >> 12;
                seq_lui(&lui);

                addi_rs1.rd = reg_rs1;
                addi_rs1.rs1 = reg_rs1;
                addi_rs1.imm = pattern;
                seq_addi(&addi_rs1);

                // load upper 32 bits
                if (XLEN > 32 && reg_rs1) {
                    if (reg_rs1 != 1 && reg_rs2 != 1) {
                        reg_helper = 1;
                    } else if (reg_rs1 != 2 && reg_rs2 != 2) {
                        reg_helper = 2;
                    } else if (reg_rs1 != 3 && reg_rs2 != 3) {
                        reg_helper = 3;
                    }

                    lui_help.rd = reg_helper;
                    lui_help.imm = ((pattern >> 32) - sign_extend((pattern >> 32) & 0xFFF)) >> 12;
                    seq_lui(&lui_help);

                    addi_help.rd = reg_helper;
                    addi_help.rs1 = reg_helper;
                    addi_help.imm = pattern >> 32;
                    seq_addi(&addi_help);

                    slli_help.rd = reg_helper;
                    slli_help.rs1 = reg_helper;
                    slli_help.imm = 32;
                    seq_slli(&slli_help);

                    // remove sign bit in rs1
                    slli_help.rd = reg_rs1;
                    slli_help.rs1 = reg_rs1;
                    slli_help.imm = 32;
                    seq_slli(&slli_help);
                    seq_srli(&slli_help);

                    rhelp.rd = reg_rs1;
                    rhelp.rs1 = reg_rs1;
                    rhelp.rs2 = reg_helper;
                    seq_or(&rhelp);
                }

                addi_rs2.rd = reg_rs2;
                addi_rs2.rs1 = reg_rs1;
                seq_addi(&addi_rs2);

                btype.rs1 = reg_rs1;
                btype.rs2 = reg_rs2;
                btype.imm = pattern;
                set_btype(&btype, btype_opcode);

                // verify wr_data is equal to value of rs1
                stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
                stype.rs1 = 0;
                stype.rs2 = reg_rs1;
                set_stype(&stype);  // Stype: copy value from [rs2] into mem[[rs1]+imm]

                rs1 = reg_rs1 ? pattern : 0;
                rs2 = reg_rs2 ? rs1 + sign_extend(addi_rs2.imm) : 0;
                if (reg_rs1 && reg_rs1 == reg_rs2) rs1 = rs2;

                // Reference transaction
                ref_req.wr = 1;
                ref_req.rd_data = 0;
                ref_req.wr_data = reg_rs1 ? rs1 : 0;
                ref_req.addr = sign_extend(stype.imm);
                sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s\n",
                    lui.str, addi_rs1.str, addi_rs2.str, btype.str, stype.str);
                push_ref(&ref_req);
            }
        }
    }
}


/* Verify Btype jumps forward 
 *Btype tests among the rest check also the brunch comparator unit
 */
void generate_btype_forward(int btype_opcode) {
    struct isa_btype btype;
    struct isa_stype stype;
    struct isa_stype dummy_stype;
    struct isa_utype lui;
    struct isa_itype addi_rs1;
    struct isa_itype addi_rs2;
    long patterns_12[SEQUENCES_NUM];
    long patterns_20[SEQUENCES_NUM];
    unsigned long pc = 0;
    long max_jump = INSTRUCTIONS_LIMIT * 4;
    long rs1;
    long rs2;
    int n;
    int next_stimulus;
    int offset;
    int fill_up;
    int expected;
    int const_offset = 4 * 4; // as amount of static commands

    printf("INFO: Generating transactions: Btype opcode %d positive jumps verification\n", btype_opcode);
    generate_bit_patterns(&patterns_12[0], 12);
    generate_bit_patterns(&patterns_20[0], 20);

    pc = const_offset - 4; // not counting the first cmd on pc 0
    max_jump -= const_offset;

    for (int reg_rs1 = 0; reg_rs1 < MAX_REG; reg_rs1++) {
        for (int reg_rs2 = 0; reg_rs2 < MAX_REG; reg_rs2++) {
            for (int mode = -1; mode < 2; mode++) {
                for (int i = 0; i < SEQUENCES_NUM; i++) {
                    if ((!reg_rs1 || !reg_rs2) && i == 4) break; // 4 sequences is enough

                    // set rs1 equal to pc of the btype command
                    lui.rd = reg_rs1;
                    lui.imm = patterns_20[i];
                    seq_lui(&lui);

                    // fill rs1 lower bits
                    addi_rs1.rd = reg_rs1;
                    addi_rs1.rs1 = reg_rs1;
                    addi_rs1.imm = patterns_12[i];
                    seq_addi(&addi_rs1);

                    // set rs2 equal to rs1 or differed by +/-1
                    addi_rs2.rd = reg_rs2;
                    addi_rs2.rs1 = reg_rs1;
                    addi_rs2.imm = mode * (rand() % 0xFFF);
                    seq_addi(&addi_rs2);

                    // --- now ready to jump ---
                    // positive numbers 4 bytes aligned
                    offset = (patterns_12[i] % max_jump) & 0x7FC;
                    if (offset < 4) offset = 4;

                    // TODO: check also 2 bytes after adding C extension
                    // jump by only positive jumps, 4 bytes aligned, not equal to zero:
                    // TODO: imm 0 will get into an infinite loop, verify 0 with csr's
                    btype.rs1 = reg_rs1;
                    btype.rs2 = reg_rs2;
                    btype.imm = offset >> 1;
                    set_btype(&btype, btype_opcode);

                    rs1 = reg_rs1 ? get_lui_base_imm_value(lui.imm, addi_rs1.imm) : 0;
                    rs2 = reg_rs2 ? rs1 + sign_extend(addi_rs2.imm) : 0;
                    if (reg_rs1 && reg_rs1 == reg_rs2) rs1 = rs2;

                    switch(btype_opcode) {
                        case Vriscv_risc_pkg::OP_B_TYPE_BEQ:
                            expected = rs1 == rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BNE:
                            expected = rs1 != rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BLT:
                            expected = rs1 < rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BGE:
                            expected = rs1 >= rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BLTU:
                            expected = (unsigned long)rs1 < (unsigned long)rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BGEU:
                            expected = (unsigned long)rs1 >= (unsigned long)rs2;
                            break;
                        default:
                            printf("ERROR: invalid BTYPE opcode provided by test\n");
                            return;
                    }

                    if (expected) {
                        // fill up with irrelevant stypes
                        fill_up = offset / 4 - 1;
                        for (n = 0; n < fill_up; n++) {
                            set_stype(&dummy_stype);
                        }
                    } else {
                        offset = 4; // stype cmd
                        fill_up = 0;
                    }

                    // verify wr_data is equal to pc of btype command
                    stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
                    stype.rs1 = 0;
                    stype.rs2 = reg_rs1;
                    set_stype(&stype);  // Stype: copy value from [rs2] into mem[[rs1]+imm]

                    // Reference transaction
                    ref_req.wr = 1;
                    ref_req.rd_data = 0;
                    ref_req.wr_data = reg_rs1 ? rs1 : 0;
                    ref_req.addr = sign_extend(stype.imm);
                    sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s(*%d)\n%s\njump %lx->%lx\n",
                        lui.str, addi_rs1.str, addi_rs2.str, btype.str, dummy_stype.str,
                        fill_up, stype.str, pc, pc + offset);
                    push_ref(&ref_req, 1);

                    if (VERBOSITY) {
                        printf("BTYPE.IMM=0x%x  max_jump=%ld  fill_up=%d  offset=0x%x  ", 
                            btype.imm, max_jump, fill_up, offset);
                        printf("pc=0x%lx  addi_rs2.imm=0x%x  rs1=0x%lx  rs2=0x%lx\n", 
                            pc, addi_rs2.imm, rs1, rs2);
                    }

                    // check if need to split mem file
                    pc += offset + const_offset;
                    max_jump -= offset + const_offset;
                    next_stimulus = 0;
                    if (i < SEQUENCES_NUM - 1 && max_jump > 0) {
                        next_stimulus = (patterns_12[i] % max_jump) & 0x7FC;
                        if (next_stimulus < 4) next_stimulus = 4;
                    }
                    if (max_jump <= 0 || pc + next_stimulus >= INSTRUCTIONS_LIMIT * 4) {
                        sqr->split();
                        pc = const_offset - 4;
                        max_jump = INSTRUCTIONS_LIMIT * 4 - const_offset;
                    }
                }
            }
        }
    }
}



/* Verify Btype jumps backward */
void generate_btype_backward(int btype_opcode) {
    struct isa_btype btype;
    struct isa_stype stype;
    struct isa_stype dummy_stype;
    struct isa_utype lui;
    struct isa_itype addi_rs1;
    struct isa_itype addi_rs2;
    struct isa_utype jal_before;
    struct isa_utype jal_after;
    long patterns_12[SEQUENCES_NUM];
    unsigned long pc = 0;
    long max_jump = INSTRUCTIONS_LIMIT * 4;
    long rs1;
    long rs2;
    int n;
    int next_stimulus;
    int offset;
    int fill_up;
    int expected;
    int const_offset = 6 * 4; // as amount of static commands

    printf("INFO: Generating transactions: Btype opcode %d negative jumps verification\n", btype_opcode);
    generate_bit_patterns(&patterns_12[0], 12);

    //pc = const_offset - 4; // not counting the first cmd on pc 0
    max_jump -= const_offset;

    for (int reg_rs1 = 0; reg_rs1 < MAX_REG; reg_rs1++) {
        for (int reg_rs2 = 0; reg_rs2 < MAX_REG; reg_rs2++) {
            for (int mode = -1; mode < 2; mode++) {
                for (int i = 0; i < SEQUENCES_NUM; i++) {
                    if ((!reg_rs1 || !reg_rs2) && i == 4) break; // 4 sequences is enough

                    // positive numbers 4 bytes aligned
                    offset = ((patterns_12[i] % max_jump) & 0x7FC);
                    if (offset < 8) offset = 8;         // min offset is two cmd backwards
                    pc += (offset - 8) + const_offset;  // predicted pc of btype

                    // set rs1 equal to pc of the btype command
                    lui.rd = reg_rs1;
                    lui.imm = (pc & 0xFFFFF) >> 12;
                    seq_lui(&lui);

                    // fill rs1 lower bits
                    addi_rs1.rd = reg_rs1;
                    addi_rs1.rs1 = reg_rs1;
                    addi_rs1.imm = (pc & 0xFFF);
                    seq_addi(&addi_rs1);

                    // set rs2 equal to rs1 or differed by +/-1
                    addi_rs2.rd = reg_rs2;
                    addi_rs2.rs1 = reg_rs1;
                    addi_rs2.imm = mode * (rand() % 0xFFF);
                    seq_addi(&addi_rs2);

                    rs1 = reg_rs1 ? get_lui_base_imm_value(lui.imm, addi_rs1.imm) : 0;
                    rs2 = reg_rs2 ? rs1 + sign_extend(addi_rs2.imm) : 0;
                    if (reg_rs1 && reg_rs1 == reg_rs2) rs1 = rs2;

                    switch(btype_opcode) {
                        case Vriscv_risc_pkg::OP_B_TYPE_BEQ:
                            expected = rs1 == rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BNE:
                            expected = rs1 != rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BLT:
                            expected = rs1 < rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BGE:
                            expected = rs1 >= rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BLTU:
                            expected = (unsigned long)rs1 < (unsigned long)rs2;
                            break;
                        case Vriscv_risc_pkg::OP_B_TYPE_BGEU:
                            expected = (unsigned long)rs1 >= (unsigned long)rs2;
                            break;
                        default:
                            printf("ERROR: invalid BTYPE opcode provided by test\n");
                            return;
                    }

                    if (!expected) {
                        offset = 8; // btype cmd
                        fill_up = 0;
                    }

                    // jump forward to the tested command (offset + btype cmd)
                    jal_before.rd = 0;
                    jal_before.imm = (offset + 4) >> 1;
                    seq_jal(&jal_before);

                    // verify wr_data is equal to pc of btype command
                    stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // positive ranges, 4 bytes aligned
                    stype.rs1 = 0;
                    stype.rs2 = reg_rs1;
                    set_stype(&stype);  // Stype: copy value from [rs2] into mem[[rs1]+imm]

                    // jump again to right after the tested btype to proceed with test
                    jal_after.imm = offset >> 1;
                    seq_jal(&jal_after);

                    if (expected) {
                        // fill up with irrelevant stypes
                        fill_up = offset / 4 - 2;
                        for (n = 0; n < fill_up; n++) {
                            set_stype(&dummy_stype);
                        }
                    }

                    // --- now ready to jump ---
                    // TODO: check also 2 bytes after adding C extension
                    // jump by only positive jumps, 4 bytes aligned, not equal to zero:
                    // TODO: imm 0 will get into an infinite loop, verify 0 with csr's
                    btype.rs1 = reg_rs1;
                    btype.rs2 = reg_rs2;
                    btype.imm = 0 - (offset >> 1);
                    set_btype(&btype, btype_opcode);

                    // Reference transaction
                    if (expected) {
                        // if no jump then not setting reference
                        ref_req.wr = 1;
                        ref_req.rd_data = 0;
                        ref_req.wr_data = reg_rs1 ? rs1 : 0;
                        ref_req.addr = sign_extend(stype.imm);
                        sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s\n%s\n%s(*%d)\n%s\njump %lx->%lx\n",
                            lui.str, addi_rs1.str, addi_rs2.str, jal_before.str,
                            stype.str, jal_after.str, dummy_stype.str, fill_up, btype.str, pc, pc - offset);
                        push_ref(&ref_req, 1);
                    }

                    if (VERBOSITY)  {
                        printf("BTYPE.IMM=0x%x  max_jump=%ld  fill_up=%d  offset=0x%x  ", 
                            btype.imm, max_jump, fill_up, offset);
                        printf("pc=0x%lx  addi_rs2.imm=0x%x  rs1=0x%lx  rs2=0x%lx\n", 
                            pc, addi_rs2.imm, rs1, rs2);
                    }

                    // check if need to split mem file
                    pc += 4;    // align pc to be after btype cmd
                    max_jump -= offset + const_offset;
                    next_stimulus = 0;
                    if (i < SEQUENCES_NUM - 1 && max_jump > 0) {
                        next_stimulus = (patterns_12[i] % max_jump) & 0x7FC;
                        if (next_stimulus < 4) next_stimulus = 4;
                    }
                    if (max_jump <= 0 || pc + next_stimulus >= INSTRUCTIONS_LIMIT * 4) {
                        sqr->split();
                        pc = 0;
                        max_jump = INSTRUCTIONS_LIMIT * 4 - const_offset;
                    }
                }
            }
        }
    }
}
