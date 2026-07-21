#ifndef COMMON_H
#include "common.h"
#endif
#include "generator.cpp"
#include "interface.cpp"
#include "environment.cpp"
#include "test.cpp"


void print_config(int seed) {
    printf("********* TEST CONFIG *********\n");
    printf("XLEN %d\n", XLEN);
    printf("Test seed %d\n", seed);
    printf("VERBOSITY %d\n", VERBOSITY);
    printf("SEQUENCES_NUM %d\n", SEQUENCES_NUM);
    printf("CLK_PHASE %d\n", CLK_PHASE);
    printf("INSTRUCTIONS_LIMIT %d\n", INSTRUCTIONS_LIMIT);
    printf("DATA_MEMORY_DEPTH %d\n", DATA_MEMORY_DEPTH);
    printf("DATA_MEMORY_BASE_ADDR %d\n", DATA_MEMORY_BASE_ADDR);
    printf("*******************************\n");
}


void run_test(Environment* env) {

    test_acceptance(env);

    // These stypes should run before other tests
    test_stype_addr(env);
    test_stype_data(env);

    test_itype_load_addr_bits(env);
    test_itype_load_unsigned_addr_bits(env);

    test_itype_load_data_bits(env);
    test_itype_load_unsigned_data_bits(env);

    test_itype_arithmetic(env);
    test_itype_arithmetic_op32(env);

    test_rtype(env);
    test_rtype_op32(env);

    test_utype_jumps(env);

    test_btype_no_jumps(env);
    test_btype_jump_forward(env);
    test_btype_jump_backward(env);

    if (XLEN == 32) test_zicsr(env);
    test_traps(env);
}


void run_single(Environment* env) {
    test_traps(env);
}


int main (int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    if (VERBOSITY) {
        Verilated::traceEverOn(true);
        Verilated::scopesDump();    // print available scopes
    }

    // TODO: set the seed from verilator args if set
    unsigned int seed = time(NULL);
    srand(seed);
    print_config(seed);

    Interface *inf = new Interface(VERBOSITY);
    Environment* env = new Environment(inf);

    env->inf->set_clock(1);
    seq_prefill_data_memory();
    env->inf->prefill_data_memory();

    //run_single(env);
    run_test(env);

    delete env;
    exit(RETURN_CODE);
}
