#ifndef COMMON_H
#include "common.h"
#endif


void test_acceptance(Environment* env) {
    generate_stype_acceptance();
    env->main();
    printf("INFO: Finished LUI and Stype commands acceptance test\n");

    generate_itype_load_acceptance();
    env->main();
    printf("INFO: Finished Addi and Itype load commands acceptance test\n");
}


void test_stype_addr(Environment* env) {
    generate_stype_imm_lui_imm(8);
    env->main();
    printf("INFO: Finished SB command addr test\n");

    if (XLEN >= 16) {
        generate_stype_imm_lui_imm(16);
        env->main();
        printf("INFO: Finished SH command addr test\n");
    }

    if (XLEN >= 32) {
        generate_stype_imm_lui_imm(24);
        env->main();
        printf("INFO: Finished ST command addr test\n");

        generate_stype_imm_lui_imm(32);
        env->main();
        printf("INFO: Finished SW command addr test\n");
    }
    printf("INFO: Finished verification: address lines, lui imm and stype imm fields\n");
}


void test_stype_data(Environment* env) {
    generate_stype_data(8);
    env->main();
    printf("INFO: Finished SB command data test\n");

    if (XLEN >= 16) {
        generate_stype_data(16);
        env->main();
        printf("INFO: Finished SH command data test\n");
    }
    if (XLEN >= 32) {
        generate_stype_data(24);
        env->main();
        printf("INFO: Finished ST command data test\n");

        generate_stype_data(32);
        env->main();
        printf("INFO: Finished SW command data test\n");
    }
    printf("INFO: Finished verification OF DATA AND ADDRESS BUSES, STYPE, LUI, ANDI commands\n");
}


void test_itype_load_addr_bits(Environment* env) {
    generate_itype_load_address(8);
    env->main();
    printf("INFO: Finished LB command addr test\n");

    if (XLEN >= 16) {
        generate_itype_load_address(16);
        env->main();
        printf("INFO: Finished LH command addr test\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_address(24);
        env->main();
        printf("INFO: Finished LT command addr test\n");

        generate_itype_load_address(32);
        env->main();
        printf("INFO: Finished LW command addr test\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands ADDRESS bus\n");
}


void test_itype_load_unsigned_addr_bits(Environment* env) {
    generate_itype_load_address(8, 1);
    env->main();
    printf("INFO: Finished LBU command addr test\n");

    if (XLEN >= 16) {
        generate_itype_load_address(16, 1);
        env->main();
        printf("INFO: Finished LHU command addr test\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_address(32, 1);
        env->main();
        printf("INFO: Finished LWU command addr test\n");
    }
    printf("INFO: Finished verification OF Itype unsigned LOAD commands ADDRESS bus\n");
}


void test_itype_load_data_bits(Environment* env) {
    generate_itype_load_data(8);
    env->main();
    printf("INFO: Finished LB command data test\n");

    if (XLEN >= 16) {
        generate_itype_load_data(16);
        env->main();
        printf("INFO: Finished LH command data test\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_data(24);
        env->main();
        printf("INFO: Finished LT command data test\n");

        generate_itype_load_data(32);
        env->main();
        printf("INFO: Finished LW command data test\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands data bus\n");
}


void test_itype_load_unsigned_data_bits(Environment* env) {
    generate_itype_load_data(8, 1);
    env->main();
    printf("INFO: Finished LBU command data test\n");

    if (XLEN >= 16) {
        generate_itype_load_data(16, 1);
        env->main();
        printf("INFO: Finished LHU command data test\n");
    }
    if (XLEN >= 32) {
        generate_itype_load_data(32, 1);
        env->main();
        printf("INFO: Finished LWU command data test\n");
    }
    printf("INFO: Finished verification OF Itype unsigned LOAD commands data bus\n");
}
