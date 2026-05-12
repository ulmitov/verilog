#ifndef COMMON_H
#include "common.h"
#endif
#include "interface.cpp"
#include "environment.cpp"
#include "generator.cpp"
#include "test.cpp"


void print_config(int seed) {
    printf("********* TEST CONFIG *********\n");
    printf("Test seed %d\n", seed);
    printf("SEQUENCES_NUM %d\n", SEQUENCES_NUM);
    printf("CLK_PHASE %d\n", CLK_PHASE);
    printf("INSTRUCTIONS_LIMIT %d\n", INSTRUCTIONS_LIMIT);
    printf("DATA_MEMORY_DEPTH %d\n", DATA_MEMORY_DEPTH);
    printf("DATA_MEMORY_BASE_ADDR %d\n", DATA_MEMORY_BASE_ADDR);
    printf("*******************************\n");
}


void run_test(Environment* env) {

    test_acceptance(env);
/*
    test_stype_addr(env);

    test_stype_data(env);

    // note: precondition for this one: prefill data not to be changed by other tests!
    test_itype_load_addr_bits(env);

    test_itype_load_data_bits(env);*/
}


int main (int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    if (VERBOSITY) Verilated::scopesDump(); // print available scopes

    // TODO: set the seed from verilator args if exists
    unsigned int seed = time(NULL);
    srand(seed);

    print_config(seed);
    Vriscv* top = new Vriscv();
    Interface *inf = new Interface(top, VERBOSITY);
    Environment* env = new Environment(inf);

    inf->top->clk = 1;
    inf->eval_sim();

    seq_prefill_data_memory();
    inf->prefill_data_memory();

    run_test(env);

    delete env;
    delete inf;
    delete top;
    exit(RETURN_CODE);
}
