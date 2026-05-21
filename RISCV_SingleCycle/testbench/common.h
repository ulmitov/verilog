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
#define VERBOSITY 0         // if 1 then prints additional output, enables VCD dump
#endif

#define SEQUENCES_NUM 32    // how much bit patterns to apply, MINIMUM is 32
#define MAX_REG 4           // how much registers to check *** FOR FULL TEST MUST BE 32 ***

// DUT parameters
#define REGFILE_A0 0x01     // set A0 and A1 to some non x0 reg
#define REGFILE_A1 0x02


const int CLK_PHASE = 150;
const int SETUP_TIME = 3;
const int HOLD_TIME = 2;

const int XLEN = Vriscv_risc_pkg::RISCV_XLEN;
const int IALIGN = Vriscv_risc_pkg::IALIGN / 8;
const int DATA_MEMORY_DEPTH = Vriscv___024root::riscv__DOT__MEM_DEPTH;
const int DATA_MEMORY_BASE_ADDR = Vriscv_risc_pkg::DMEM_BASE_ADDRESS;
const int DATA_MEMORY_LAST_ADDR = DATA_MEMORY_BASE_ADDR + DATA_MEMORY_DEPTH;
const int DATA_MEMORY_ADDR_WIDTH = Vriscv___024root::riscv__DOT__data_mem__DOT__ADDR_WIDTH;
const int INSTRUCTIONS_LIMIT = (Vriscv___024root::riscv__DOT__instruction_mem__DOT__DEPTH / IALIGN) - 20;
const int WORD_LEN = XLEN / 8;
int RETURN_CODE = 0;


struct Transaction {
    int req;
    int wr;
    long addr;
    long wr_data;
    long rd_data;
    char str[512];      // stores the instructions chain text
    int test_id;        // id of the test phase is set here
};


extern std::queue<Transaction> ref_fifo;
extern std::queue<Transaction> drv_fifo;


struct isa_utype {
    char str[50];
    int value;
    int opcode;
    unsigned int rd = 0;    // 5 bits
    int imm = 0;            // 20 bits
};


struct isa_stype {
    char str[50];
    int value;
    long datamask;
    int opcode;
    int funct3 = 0;
    unsigned int rs1 = 0;   // 5 bits
    unsigned int rs2 = 0;   // 5 bits
    int imm = 0;            // 12 bits
};


struct isa_itype {
    char str[50];
    int value;
    long datamask;
    int opcode;
    int funct3 = 0;
    unsigned int rd = 0;    // 5 bits
    unsigned int rs1 = 0;   // 5 bits
    int imm = 0;            // 12 bits
};


struct isa_btype {
    char str[50];
    int value;
    int opcode;
    int funct3 = 0;
    unsigned int rs1 = 0;   // 5 bits
    unsigned int rs2 = 0;   // 5 bits
    int imm = 0;            // 12 bits
};


struct isa_rtype {
    char str[50];
    int value;
    int opcode;
    int funct3 = 0;
    unsigned int rd = 0;    // 5 bits
    unsigned int rs1 = 0;   // 5 bits
    unsigned int rs2 = 0;   // 5 bits
    unsigned int funct7 = 0;// 7 bits
};
