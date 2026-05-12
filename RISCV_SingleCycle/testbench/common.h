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


// Test parameters
#ifndef VERBOSITY
#define VERBOSITY 1
#endif
#define SEQUENCES_NUM 40
int RETURN_CODE = 0;


// DUT parameters
#define REGFILE_A0 0x01 // setting A0 and A1 to non zero reg
#define REGFILE_A1 0x02

const int CLK_PHASE = 150;
const int SETUP_TIME = 3;
const int HOLD_TIME = 2;

const int XLEN = Vriscv_risc_pkg::RISCV_XLEN;
const int DATA_MEMORY_DEPTH = Vriscv___024root::riscv__DOT__MEM_DEPTH;
const int INSTRUCTIONS_LIMIT = (Vriscv___024root::riscv__DOT__instruction_mem__DOT__DEPTH / 4) - 20;
const int DATA_MEMORY_BASE_ADDR = Vriscv_risc_pkg::DMEM_BASE_ADDRESS;
const int DATA_MEMORY_LAST_ADDR = DATA_MEMORY_BASE_ADDR + DATA_MEMORY_DEPTH;


struct Transaction {
    int req;
    int wr;
    unsigned long int addr;
    unsigned long int wr_data;
    unsigned long int rd_data;
    int test_id;
    char str[360];
};

extern std::queue<Transaction> ref_fifo;
extern std::queue<Transaction> drv_fifo;


// load (imm << 12) into reg[rd]
struct isa_lui {
    char str[50];
    int opcode;
    unsigned int rd;    // 5 bits
    unsigned int imm;   // 20 bits
};


// S type: copy value in reg[rs2] into mem[reg[rs1]+imm]. Imm is sign extended.
struct isa_stype {
    char str[50];
    int opcode;
    int funct3;
    unsigned int rs1;   // 5 bits
    unsigned int rs2;   // 5 bits
    signed int imm;     // 12 bits
};


// I type: rd = rs1 + imm
struct isa_itype {
    char str[50];
    int opcode;
    int funct3;
    unsigned int rd;    // 5 bits
    unsigned int rs1;   // 5 bits
    signed int imm;     // 12 bits
};
