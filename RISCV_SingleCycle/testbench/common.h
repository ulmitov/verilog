#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <queue>

#include <verilated.h>
#include <verilated_vcd_c.h>
#include "verilated_cov.h"
#include "Vriscv_risc_pkg.h"
#include "Vriscv__Dpi.h"
#include "Vriscv.h"
#include "Vriscv___024root.h"

// Globals
#define COMMON_H


// Test parameters:
#ifndef VERBOSITY
// prints additional output, enables VCD dump
#define VERBOSITY 1
#endif

// how much bit patterns to apply. min is 30.
#define SEQUENCES_NUM 30

// how much register files increment to use in generators
// FOR FULL TEST MUST BE 1 - if bigger, significantly reduces run time
#define REG_FILE_INCR 8


int RETURN_CODE = 0;
int INSTRUCTIONS_LIMIT = (Vriscv___024root::riscv__DOT__instruction_mem__DOT__DEPTH / (Vriscv_risc_pkg::IALIGN / 8)) - 20;


// DUT parameters
#define REGFILE_A0 0x01 // setting A0 and A1 to non zero reg
#define REGFILE_A1 0x02

const int CLK_PHASE = 150;
const int SETUP_TIME = 3;
const int HOLD_TIME = 2;

const int XLEN = Vriscv_risc_pkg::RISCV_XLEN;
const int DATA_MEMORY_DEPTH = Vriscv___024root::riscv__DOT__MEM_DEPTH;
const int DATA_MEMORY_BASE_ADDR = Vriscv_risc_pkg::DMEM_BASE_ADDRESS;
const int DATA_MEMORY_LAST_ADDR = DATA_MEMORY_BASE_ADDR + DATA_MEMORY_DEPTH;
const int DATA_MEMORY_ADDR_WIDTH = Vriscv___024root::riscv__DOT__data_mem__DOT__ADDR_WIDTH;
const int WORD_LEN = XLEN / 8;


struct Transaction {
    int req;
    int wr;
    long addr;
    long wr_data;
    long rd_data;
    char str[360];
    int test_id;
};


extern std::queue<Transaction> ref_fifo;
extern std::queue<Transaction> drv_fifo;


struct isa_utype {
    char str[50];
    int opcode;
    unsigned int rd;    // 5 bits
    unsigned int imm;   // 20 bits
};


struct isa_stype {
    char str[50];
    long datamask;
    int opcode;
    int funct3;
    unsigned int rs1;   // 5 bits
    unsigned int rs2;   // 5 bits
    signed int imm;     // 12 bits
};


struct isa_itype {
    char str[50];
    long datamask;
    int opcode;
    int funct3;
    unsigned int rd;    // 5 bits
    unsigned int rs1;   // 5 bits
    signed int imm;     // 12 bits
};


struct isa_btype {
    char str[50];
    int opcode;
    int funct3;
    unsigned int rs1;   // 5 bits
    unsigned int rs2;   // 5 bits
    signed int imm;     // 12 bits
};


struct isa_rtype {
    char str[50];
    int opcode;
    int funct3;
    unsigned int rd;    // 5 bits
    unsigned int rs1;   // 5 bits
    unsigned int rs2;   // 5 bits
    unsigned int funct7;// 7 bits
};
