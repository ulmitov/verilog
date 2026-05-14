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
    int i;
    unsigned long long mask_ff = (1ULL << bits_width) - 1;
    //printf("MASK %0llx  bits_width %d   res %0x \n", mask_ff, bits_width, (1 << bits_width) - 1);
    // high to low and low to high
    *arr++ = 0;
    *arr++ = mask_ff;
    *arr++ = 0;
    *arr++ = mask_ff;
    // some patterns
    *arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
    *arr++ = 0x5555555555555555 & mask_ff;
    *arr++ = 0xAAAAAAAAAAAAAAAA & mask_ff;
    *arr++ = 0xDBDBDBDBDBDBDBDB & mask_ff;
    *arr++ = 0xB6B6B6B6B6B6B6B6 & mask_ff;
    *arr++ = 0x6D6D6D6D6D6D6D6D & mask_ff;
    // toggle bit by bit
    for (i = 0; i < bits_width; i++) {
        *arr++ = 1 << i;
    }
    // fill up to requested length with random values
    for (i = bits_width + 10; i < length; i++) {
        if (rand_max) {
            *arr++ = mask_ff & (rand_min + rand() % rand_max);
        } else {
            *arr++ = mask_ff & (rand_min + rand());
        }
    }
}


/* Sign extend 32 bit */
int sign_extend(int data, int bits_num = 12) {  // For 64 bits will need to return long
    bits_num = 32 - bits_num;
    data = data << bits_num;
    data = data >> bits_num;
    return data & 0xFFFFFFFF;
}

long int get_lui_base_imm_value(long int lui_base_val, long int imm_val, int imm_bits_num = 12) {
    return (lui_base_val << 12) + sign_extend(imm_val, imm_bits_num);
}


/* Verify commands with zero values and check that Reg[x0] is not overriden by LUI */
void generate_stype_acceptance() {
    struct isa_lui lui_base;
    struct isa_stype stype;
    printf("INFO: Generating transactions: LUI and Stype commands with zero values\n");

    for (int block_size = 1; block_size < 5; block_size++) {
        // lui rd will hold the base address for stype
        lui_base.rd = 0;
        lui_base.imm = rand() % 0x100000;
        seq_lui(&lui_base);

        // Stype: copy value from [rs2] into mem[[rs1]+imm]
        stype.imm = 0;
        stype.rs1 = 0;
        stype.rs2 = 0;

        switch(block_size * 8) {
            case 8:
                seq_sb(&stype);
                break;
            case 16:
                seq_sh(&stype);
                break;
            case 24:
                seq_st(&stype);
                break;
            case 32:
                seq_sw(&stype);
                break;
            default:
                printf("ERROR: invalid bits_width provided by test");
                return;
        }
        ref_req.wr = 1;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        ref_req.addr = 0;
        sprintf(ref_req.str, "%s\n%s\n", lui_base.str, stype.str);
        push_ref(&ref_req);
    }
}


void generate_stype_imm_lui_imm(int bits_width) {
    struct isa_lui lui_base;
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

        switch(bits_width) {
            case 8:
                seq_sb(&stype);
                break;
            case 16:
                seq_sh(&stype);
                break;
            case 24:
                seq_st(&stype);
                break;
            case 32:
                seq_sw(&stype);
                break;
            default:
                printf("ERROR: invalid bits_width provided by test");
                return;
        }
        // expect addr to be: lui_base.imm << 12 + (signed)stype.imm
        ref_req.wr = 1;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        ref_req.addr = (lui_base.imm << 12) + sign_extend(stype.imm);
        sprintf(ref_req.str, "%s\n%s\n", lui_base.str, stype.str);
        push_ref(&ref_req);
    }
}


void generate_stype_data(int bits_width) {
    struct isa_lui lui_base;
    struct isa_lui lui_data;
    struct isa_itype addi;
    struct isa_stype stype;
    unsigned long int stimulus_12[SEQUENCES_NUM];
    unsigned long int stimulus_20[SEQUENCES_NUM];
    int data_mask;

    printf("INFO: Generating transactions: %d bits Stype data verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    generate_bit_stimulus(&stimulus_20[0], 20);

    // TODO: if the loops get bigger then move it inside the loops
    lui_base.rd = REGFILE_A0;
    lui_base.imm = DATA_MEMORY_BASE_ADDR >> 12;
    seq_lui(&lui_base);

    for (int reg = 1; reg < 32; reg++) {
        if (reg == REGFILE_A0) continue;

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set the upper imm value
            lui_data.rd = reg;
            lui_data.imm = stimulus_20[i];
            seq_lui(&lui_data);

            // set rd = rs1 + imm
            addi.rd = reg;
            addi.rs1 = reg;
            addi.imm = stimulus_12[i];
            seq_addi(&addi);

            // Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = (stimulus_12[i] / WORD_LEN) * WORD_LEN;    // 4 bytes aligned
            stype.rs1 = lui_base.rd;
            stype.rs2 = reg;

            switch(bits_width) {
                case 8:
                    seq_sb(&stype);
                    data_mask = 0xFF;
                    break;
                case 16:
                    seq_sh(&stype);
                    data_mask = 0xFFFF;
                    break;
                case 24:
                    seq_st(&stype);
                    data_mask = 0xFFFFFF;
                    break;
                case 32:
                    seq_sw(&stype);
                    data_mask = 0xFFFFFFFF;
                    break;
                default:
                    printf("ERROR: invalid bits_width provided by test");
                    return;
            }
            // expect wr_data to be: lui_data.imm << 12 + (signed)addi.imm & (width mask)
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.wr_data = ((lui_data.imm << 12) + sign_extend(addi.imm)) & data_mask;
            ref_req.addr = (lui_base.imm << 12) + sign_extend(stype.imm);
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n",
                lui_base.str, lui_data.str, addi.str, stype.str);
            push_ref(&ref_req);
        }
    }
}


/* Verify commands with zero values */
void generate_itype_load_acceptance() {
    struct isa_lui lui_base;
    struct isa_itype addi;
    struct isa_itype load;
    int data_mask;

    printf("INFO: Generating transactions: Itype load command acceptance\n");

    for (int block_size = 1; block_size < 5; block_size++) {
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

        switch(block_size * 8) {
            case 8:
                seq_lb(&load);
                data_mask = 0xFF;
                break;
            case 16:
                seq_lh(&load);
                data_mask = 0xFFFF;
                break;
            case 24:
                seq_lt(&load);
                data_mask = 0xFFFFFF;
                break;
            case 32:
                seq_lw(&load);
                data_mask = 0xFFFFFFFF;
                break;
            default:
                printf("ERROR: invalid bits_width provided by test");
                return;
        }

        ref_req.wr = 0;
        ref_req.rd_data = 0;
        ref_req.wr_data = 0;
        ref_req.addr = 0;
        sprintf(ref_req.str, "%s\n%s\n%s\n", lui_base.str, addi.str, load.str);
        push_ref(&ref_req);
    }
}


void generate_itype_load_address(int bits_width, char unsigned_commands = 0) {
    struct isa_lui lui_base;
    struct isa_itype load;
    struct isa_stype stype;
    unsigned long int stimulus_12[SEQUENCES_NUM];
    unsigned long int stimulus_20[SEQUENCES_NUM];
    int data_mask;

    printf("INFO: Generating transactions: %d bits Itype load command addr verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    generate_bit_stimulus(&stimulus_20[0], 20);

    for (int dreg = 1; dreg < 32; dreg++) {

        for (int i = 0; i < SEQUENCES_NUM; i++) {
            // set into reg the address for load
            lui_base.rd = dreg;
            lui_base.imm = stimulus_20[i];
            seq_lui(&lui_base);

            // Load Itype: copy value from mem[[rs1]+imm] into reg[rd]
            load.rd = dreg < 31 ? dreg + 1 : 0;
            load.rs1 = dreg;
            load.imm = stimulus_12[i];

            switch(bits_width) {
                case 8:
                    if (unsigned_commands) {
                        seq_lbu(&load);
                    } else {
                        seq_lb(&load);
                    }
                    data_mask = 0xFF;
                    break;
                case 16:
                    if (unsigned_commands) {
                        seq_lhu(&load);
                    } else {
                        seq_lh(&load);
                    }
                    data_mask = 0xFFFF;
                    break;
                case 24:
                    seq_lt(&load);
                    data_mask = 0xFFFFFF;
                    break;
                case 32:
                    if (unsigned_commands) {
                        seq_lwu(&load);
                    } else {
                        seq_lw(&load);
                    }
                    data_mask = 0xFFFFFFFF;
                    break;
                default:
                    printf("ERROR: invalid bits_width provided by test");
                    return;
            }

            ref_req.wr = 0;
            ref_req.wr_data = 0;
            ref_req.addr = (lui_base.imm << 12) + sign_extend(load.imm);
            // precondition: data memory was prefilled with each address holding 4 bytes equal to the address value!
            if (ref_req.addr >= DATA_MEMORY_BASE_ADDR && ref_req.addr < DATA_MEMORY_LAST_ADDR) {
                ref_req.rd_data = ref_req.addr & data_mask;
            } else {
                ref_req.rd_data = 0;  // TODO Drive value?
            }
            sprintf(ref_req.str, "%s\n%s\n", lui_base.str, load.str);
            push_ref(&ref_req, 1);

            // Verify data was loaded into the reg Stype: copy value from [rs2] into mem[[rs1]+imm]
            stype.imm = load.imm;
            stype.rs1 = load.rs1;
            stype.rs2 = load.rd;

            switch(bits_width) {
                case 8:
                    seq_sb(&stype);
                    data_mask = 0xFF;
                    break;
                case 16:
                    seq_sh(&stype);
                    data_mask = 0xFFFF;
                    break;
                case 24:
                    seq_st(&stype);
                    data_mask = 0xFFFFFF;
                    break;
                case 32:
                    seq_sw(&stype);
                    data_mask = 0xFFFFFFFF;
                    break;
                default:
                    printf("ERROR: invalid bits_width provided by test");
                    return;
            }
            ref_req.wr = 1;
            if (!load.rd) {
                ref_req.wr_data = 0;
            } else if (unsigned_commands) {
                ref_req.wr_data = ref_req.rd_data & data_mask;
            } else {
                ref_req.wr_data = sign_extend(ref_req.rd_data & data_mask, bits_width);
            }
            ref_req.rd_data = 0;
            // ref_req.addr remains same
            sprintf(ref_req.str, "%s\n%s\n%s\n", lui_base.str, load.str, stype.str);
            push_ref(&ref_req);
        }
    }
}


void generate_itype_load_data(int bits_width, char unsigned_commands = 0) {
    struct isa_lui lui_base;
    struct isa_lui lui_data;
    struct isa_lui lui_base_stype;
    struct isa_itype addi;
    struct isa_itype load;
    struct isa_stype stype;
    unsigned long int stimulus_12[SEQUENCES_NUM];
    //unsigned long int stimulus_20[SEQUENCES_NUM];
    int data_mask;
    long int reg_val;

    printf("INFO: Generating transactions: %d bits Itype load command data verification\n", bits_width);
    generate_bit_stimulus(&stimulus_12[0], 12);
    //generate_bit_stimulus(&stimulus_20[0], 20);

    for (int dreg = 1; dreg < 32; dreg++) {
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

            switch(bits_width) {
                case 8:
                    if (unsigned_commands) {
                        seq_lbu(&load);
                    } else {
                        seq_lb(&load);
                    }
                    data_mask = 0xFF;
                    break;
                case 16:
                    if (unsigned_commands) {
                        seq_lhu(&load);
                    } else {
                        seq_lh(&load);
                    }
                    data_mask = 0xFFFF;
                    break;
                case 24:
                    seq_lt(&load);
                    data_mask = 0xFFFFFF;
                    break;
                case 32:
                    if (unsigned_commands) {
                        seq_lwu(&load);
                    } else {
                        seq_lw(&load);
                    }
                    data_mask = 0xFFFFFFFF;
                    break;
                default:
                    printf("ERROR: invalid bits_width provided by test");
                    return;
            }

            // driver to set rd_data with random data
            drv_req.wr = 0;
            drv_req.addr = (lui_base.imm << 12) + sign_extend(load.imm);
            // TODO: for external memory, add block size logic in load commands, then remove the data mask from here:
            // also apply stimulus here, need to verify high to low, etc...
            drv_req.rd_data = rand() & data_mask;
            sprintf(drv_req.str, "%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str);
            drv_req.test_id = sqr->split_count;
            drv_fifo.push(drv_req);
            //if (VERBOSITY) {
                printf("DEBUG: GEN: pushed to driver transaction with addr %0lx, rd_data %0lx\n",
                drv_req.addr, drv_req.rd_data);
            //}

            ref_req.wr = 0;
            ref_req.wr_data = 0;
            ref_req.addr = drv_req.addr;
            ref_req.rd_data = drv_req.rd_data;
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str);
            push_ref(&ref_req, 1);

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

            switch(XLEN) {
                case 8:
                    seq_sb(&stype);
                    break;
                case 16:
                    seq_sh(&stype);
                    break;
                case 32:
                    seq_sw(&stype);
                    break;
                default:
                    printf("ERROR: unsupported XLEN\n");
                    return;
            }

            reg_val = (lui_data.imm << 12) + sign_extend(addi.imm);
            ref_req.wr = 1;
            ref_req.rd_data = 0;
            ref_req.addr = (lui_base_stype.imm << 12) + sign_extend(stype.imm);
            if (!dreg) {
                ref_req.wr_data = 0;
            } else if (unsigned_commands) {
                ref_req.wr_data = drv_req.rd_data;
            } else {
                ref_req.wr_data = sign_extend(drv_req.rd_data, bits_width) & 0x00FFFFFFFF;  // masking since in tr it is long
            }
            sprintf(ref_req.str, "%s\n%s\n%s\n%s\n%s\n%s\n",
                    lui_base.str, lui_data.str, addi.str, load.str, lui_base_stype.str, stype.str);
            push_ref(&ref_req);
        }
    }
}
