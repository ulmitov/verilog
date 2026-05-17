#ifndef COMMON_H
#include "common.h"
#endif


void test_acceptance(Environment* env) {
    generate_stype_acceptance();
    generate_itype_load_acceptance();
    env->main();
    printf("INFO: Finished LUI + Addi + Stype + Itype load commands acceptance test\n\n");
}


void test_stype_addr(Environment* env) {
    generate_stype_imm_lui_imm(8);
    env->main();
    printf("INFO: Finished SB command addr test\n\n");

    if (XLEN >= 16) {
        generate_stype_imm_lui_imm(16);
        env->main();
        printf("INFO: Finished SH command addr test\n\n");
    }

    if (XLEN >= 32) {
        generate_stype_imm_lui_imm(24);
        env->main();
        printf("INFO: Finished ST command addr test\n\n");

        generate_stype_imm_lui_imm(32);
        env->main();
        printf("INFO: Finished SW command addr test\n\n");
    }
    if (XLEN >= 64) {
        generate_stype_imm_lui_imm(64);
        env->main();
        printf("INFO: Finished SD command addr test\n\n");
    }
    printf("INFO: Finished verification: address lines, lui imm and stype imm fields\n");
}


void test_stype_data(Environment* env) {
    generate_stype_data(8);
    env->main();
    printf("INFO: Finished SB command data test\n\n");

    if (XLEN >= 16) {
        generate_stype_data(16);
        env->main();
        printf("INFO: Finished SH command data test\n\n");
    }
    if (XLEN >= 32) {
        generate_stype_data(24);
        env->main();
        printf("INFO: Finished ST command data test\n\n");

        generate_stype_data(32);
        env->main();
        printf("INFO: Finished SW command data test\n\n");
    }
    if (XLEN >= 64) {
        generate_stype_data(64);
        env->main();
        printf("INFO: Finished SD command data test\n\n");
    }
    printf("INFO: Finished verification OF DATA AND ADDRESS BUSES, STYPE, LUI, ANDI commands\n");
}


void test_itype_load_addr_bits(Environment* env) {
    generate_itype_load_address(8);
    env->main();
    printf("INFO: Finished LB command addr test\n\n");

    if (XLEN >= 16) {
        generate_itype_load_address(16);
        env->main();
        printf("INFO: Finished LH command addr test\n\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_address(32);
        env->main();
        printf("INFO: Finished LW command addr test\n\n");
    }
    if (XLEN >= 64) {
        generate_itype_load_address(64);
        env->main();
        printf("INFO: Finished LD command addr test\n\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands ADDRESS bus\n");
}


void test_itype_load_unsigned_addr_bits(Environment* env) {
    generate_itype_load_address(8, 1);
    env->main();
    printf("INFO: Finished LBU command addr test\n\n");

    if (XLEN >= 16) {
        generate_itype_load_address(16, 1);
        env->main();
        printf("INFO: Finished LHU command addr test\n\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_address(24, 1);
        env->main();
        printf("INFO: Finished LT command addr test\n\n");

        generate_itype_load_address(32, 1);
        env->main();
        printf("INFO: Finished LWU command addr test\n\n");
    }
    printf("INFO: Finished verification OF Itype unsigned LOAD commands ADDRESS bus\n");
}


void test_itype_load_data_bits(Environment* env) {
    generate_itype_load_data(8);
    env->main();
    printf("INFO: Finished LB command data test\n\n");

    if (XLEN >= 16) {
        generate_itype_load_data(16);
        env->main();
        printf("INFO: Finished LH command data test\n\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_data(32);
        env->main();
        printf("INFO: Finished LW command data test\n\n");
    }
    if (XLEN >= 64) {
        generate_itype_load_data(64);
        env->main();
        printf("INFO: Finished LD command data test\n\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands data bus\n");
}


void test_itype_load_unsigned_data_bits(Environment* env) {
    generate_itype_load_data(8, 1);
    env->main();
    printf("INFO: Finished LBU command data test\n\n");

    if (XLEN >= 16) {
        generate_itype_load_data(16, 1);
        env->main();
        printf("INFO: Finished LHU command data test\n\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_data(24, 1);
        env->main();
        printf("INFO: Finished LT command data test\n\n");

        generate_itype_load_data(32, 1);
        env->main();
        printf("INFO: Finished LWU command data test\n\n");
    }
    printf("INFO: Finished verification OF Itype unsigned LOAD commands data bus\n");
}


void test_itype_arithmetic(Environment* env) {

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_ADD);
    env->main();
    printf("INFO: Finished ADDI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_XOR);
    env->main();
    printf("INFO: Finished XORI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_OR);
    env->main();
    printf("INFO: Finished ORI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_AND);
    env->main();
    printf("INFO: Finished ANDI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SLL);
    env->main();
    printf("INFO: Finished SLLI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SRL);
    env->main();
    printf("INFO: Finished SRLI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SRA);
    env->main();
    printf("INFO: Finished SRAI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SLT);
    env->main();
    printf("INFO: Finished SLTI command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SLTU);
    env->main();
    printf("INFO: Finished SLTIU command test\n\n");

}



void test_itype_arithmetic_op32(Environment* env) {
    if (XLEN < 64) return;
    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_ADD, 1);
    env->main();
    printf("INFO: Finished ADDIW command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SLL, 1);
    env->main();
    printf("INFO: Finished SLLIW command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SRL, 1);
    env->main();
    printf("INFO: Finished SRLIW command test\n\n");

    generate_itype_arithmetic(Vriscv_risc_pkg::OP_ALU_SRA, 1);
    env->main();
    printf("INFO: Finished SRAIW command test\n\n");
}
