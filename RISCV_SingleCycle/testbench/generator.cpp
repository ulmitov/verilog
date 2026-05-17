#ifndef COMMON_H
#include "common.h"
#endif
#include "sequences.cpp"

struct Transaction ref_req;
struct Transaction drv_req;


void generate_bit_stimulus(
    long unsigned int *arr,
    int bits_width,
    int length = SEQUENCES_NUM,
    unsigned long rand_min = 0,
    unsigned long rand_max = 0
) {
    unsigned long long mask_ff = (1ULL << bits_width) - 1;
    // high to low and low to high
    *arr++ = 0;
    *arr++ = mask_ff;
    *arr++ = 0;
    *arr++ = mask_ff;
    length -= 4;

    // toggle bit by bit
    for (int i = 0; i < bits_width; i++) *arr++ = 1 << i;
    length -= bits_width;

    if (length > 6) {
        // some patterns
        *arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
        *arr++ = 0x5555555555555555 & mask_ff;
        *arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
        *arr++ = 0xDBDBDBDBDBDBDBDB & mask_ff;
        *arr++ = 0xB6B6B6B6B6B6B6B6 & mask_ff;
        *arr++ = 0x6D6D6D6D6D6D6D6D & mask_ff;
        length -= 6;
    }
    
    // fill with random values up to requested array length
    while (length-- > 0) {
        if (rand_max) {
            *arr++ = mask_ff & (rand_min + rand() % rand_max);
        } else {
            *arr++ = mask_ff & (rand_min + rand());
        }
    }
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
        lui_base.imm = rand() % 0x100000;
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
    unsigned long int stimulus_12[SEQUENCES_NUM];
    unsigned long int stimulus_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Stype rs1 imm and lui imm fields verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    generate_bit_stimulus(&stimulus_20[0], 20);

    for (int i = 0; i < SEQUENCES_NUM; i++) {
        // lui rd will hold the base address for stype
        lui_base.rd = REGFILE_A0;
        lui_base.imm = stimulus_20[i];
        seq_lui(&lui_base);

        // Stype: copy value from [rs2] into mem[[rs1]+imm]
        stype.imm = stimulus_12[i];
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
    unsigned long int stimulus_12[SEQUENCES_NUM];
    unsigned long int stimulus_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Stype data verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    generate_bit_stimulus(&stimulus_20[0], 20);

    // TODO: if the loops get bigger then move it inside the loops
    lui_base.rd = REGFILE_A0;
    lui_base.imm = DATA_MEMORY_BASE_ADDR >> 12;
    seq_lui(&lui_base);

    for (int dreg = 1; dreg < 32; dreg += REG_FILE_INCR) {
        if (dreg == REGFILE_A0) continue;

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set the upper imm value
            lui_data.rd = dreg;
            lui_data.imm = stimulus_20[i];
            seq_lui(&lui_data);

            // set rd = rs1 + imm
            addi.rd = dreg;
            addi.rs1 = dreg;
            addi.imm = stimulus_12[i];
            seq_addi(&addi);

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = (stimulus_12[i] / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
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
        lui_base.imm = rand() % 0x100000;
        seq_lui(&lui_base);

        addi.rd = 0;
        addi.rs1 = 0;
        addi.imm = rand() % 0x1000;
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
    unsigned long int stimulus_12[SEQUENCES_NUM];
    unsigned long int stimulus_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Itype load command addr verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    generate_bit_stimulus(&stimulus_20[0], 20);

    for (int dreg = 1; dreg < 32; dreg += REG_FILE_INCR) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set into reg the address for load
            lui_base.rd = dreg;
            lui_base.imm = stimulus_20[i];
            seq_lui(&lui_base);

            // Load Itype: copy value from mem[[rs1]+imm] into reg[rd]
            load.rd = dreg < 31 ? dreg + 1 : 0;
            load.rs1 = dreg;
            load.imm = stimulus_12[i];
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
    unsigned long int stimulus_12[SEQUENCES_NUM];
    //unsigned long int stimulus_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: %d bits Itype load command data verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    //generate_bit_stimulus(&stimulus_20[0], 20);

    for (int dreg = 1; dreg < 32; dreg += REG_FILE_INCR) {
        if (dreg == REGFILE_A0 || dreg == REGFILE_A1) continue;

        for (int i = 0; i < SEQUENCES_NUM; i++) {

            // set base address to read outside of data memory
            // this address should be unique as it will be used by driver to drive rd data
            lui_base.rd = REGFILE_A1;
            lui_base.imm = 0xA0000 + rand() % 0x60000; // TODO: set random vals or stimulus?
            seq_lui(&lui_base);

            // fill data destination reg high bits
            lui_data.rd = dreg;
            lui_data.imm = rand() % 0x100000;
            seq_lui(&lui_data);

            // fill data destination reg lower bits
            addi.rd = dreg;
            addi.rs1 = dreg;
            addi.imm = rand() % 0x1000;
            seq_addi(&addi);

            // Load Itype: copy value from mem[[rs1]+imm] into reg[rd]
            load.rd = dreg;
            load.rs1 = lui_base.rd;
            load.imm = (stimulus_12[i]);// / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
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
            sprintf(drv_req.str, "%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str);
            drv_req.test_id = sqr->split_count;
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
            stype.imm = ((rand() % 0x1000) / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
            stype.rs1 = lui_base_stype.rd;
            stype.rs2 = dreg;
            set_stype(&stype, XLEN);

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
    unsigned long int stimulus_12[SEQUENCES_NUM];
    //unsigned long int stimulus_20[SEQUENCES_NUM];

    printf("INFO: Generating transactions: Itype arithmetic commands with opcode %d\n", opcode);
    generate_bit_stimulus(&stimulus_12[0], 12);
    //generate_bit_stimulus(&stimulus_20[0], 20);

    // first loop running with zeros, i.e acceptance test!
    for (int sreg = 0; sreg < 32; sreg += REG_FILE_INCR) {
        for (int dreg = 0; dreg < 32; dreg += REG_FILE_INCR) {
            for (int i = 0; i < SEQUENCES_NUM; i++) {
                if (dreg == 0 && i == 4) break; // for x0 4 first sequences is enough

                // lui rd will hold the upper bits for itype.rs1
                lui_base.rd = sreg;
                lui_base.imm = rand() % 0x100000;   // stimulus_20[i];
                seq_lui(&lui_base);

                // fill itype.rs1 lower bits
                addi.rd = sreg;
                addi.rs1 = sreg;
                addi.imm = rand() % 0x1000;
                seq_addi(&addi);

                // rd = rs1 + imm
                itype.rd = dreg;
                itype.rs1 = sreg;
                itype.imm = stimulus_12[i];
                set_itype_arithmetic(&itype, opcode, op32);

                // Stype: copy value from [rs2] into mem[[rs1]+imm]
                stype.imm = ((rand() % 0x700) / WORD_LEN) * WORD_LEN;    // only positive ranges, 4 bytes aligned
                stype.rs1 = 0;              // x0 is always 0 so in this test always saving to mem range 0 +/- 4096
                stype.rs2 = itype.rd;
                set_stype(&stype, XLEN);

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
