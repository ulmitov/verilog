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
    printf("INFO: Finished SB command test\n");

    if (XLEN >= 16) {
        generate_stype_imm_lui_imm(16);
        env->main();
        printf("INFO: Finished SH command test\n");
    }

    if (XLEN >= 32) {
        generate_stype_imm_lui_imm(24);
        env->main();
        printf("INFO: Finished ST command test\n");

        generate_stype_imm_lui_imm(32);
        env->main();
        printf("INFO: Finished SW command test\n");
    }
    printf("INFO: Finished verification: address lines, lui imm and stype imm fields\n");
}


void test_stype_data(Environment* env) {
    generate_stype_data(8);
    env->main();
    printf("INFO: Finished SB command test\n");

    if (XLEN >= 16) {
        generate_stype_data(16);
        env->main();
        printf("INFO: Finished SH command test\n");
    }
    if (XLEN >= 32) {
        generate_stype_data(24);
        env->main();
        printf("INFO: Finished ST command test\n");

        generate_stype_data(32);
        env->main();
        printf("INFO: Finished SW command test\n");
    }
    printf("INFO: Finished verification OF DATA AND ADDRESS BUSES, STYPE, LUI, ANDI commands\n");
}


void test_itype_load_addr_bits(Environment* env) {
    generate_itype_load_address(8);
    env->main();
    printf("INFO: Finished LB command test\n");

    if (XLEN >= 16) {
        generate_itype_load_address(16);
        env->main();
        printf("INFO: Finished LH command test\n");
    }
    if (XLEN >= 32) {
        //generate_itype_load_address(24);
        //env->main();
        //printf("INFO: Finished LT command test\n");

        generate_itype_load_address(32);
        env->main();
        printf("INFO: Finished LW command test\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands ADDRESS bus\n");
}


void test_itype_load_data_bits(Environment* env) {
    generate_itype_load_data(8);
    env->main();
    printf("INFO: Finished LB command test\n");

    if (XLEN >= 16) {
        generate_itype_load_data(16);
        env->main();
        printf("INFO: Finished LH command test\n");
    }
    if (XLEN >= 32) {
        //generate_itype_load_data(24);
        //env->main();
        //printf("INFO: Finished LT command test\n");

        generate_itype_load_data(32);
        env->main();
        printf("INFO: Finished LW command test\n");
    }
    printf("INFO: Finished verification OF Itype LOAD commands data bus\n");
}
