#ifndef COMMON_H
#include "common.h"
#endif


class Interface {
public:
    unsigned long timestamp;
    Vriscv *top;
    VerilatedVcdC* vcd;
    
    Interface(char vcdc = 0):
        timestamp(0),
        top(new Vriscv()),
        vcd(vcdc ? new VerilatedVcdC() : nullptr)
    {
        if (vcdc) {
            top->trace(vcd, 99);
            vcd->open("vcd/RISCV_DV.vcd");
        }
    }

    ~Interface() {
        char vcd_file_path[50];
        wait_ticks(10);
        printf("[%lu] INFO: End of testbench\n", timestamp);
        top->eval();
        if (vcd) {
            vcd->close();
            delete vcd;
        }
        top->final();
        sprintf(vcd_file_path, "vcd/cov_riscdv_%d.dat", XLEN);
        VerilatedCov::write(vcd_file_path);
        delete top;
    }

    char req() {
        return top->dmem_req;
    }
    char wr() {
        return top->dmem_wr;
    }
    unsigned int addr() {
        return top->dmem_addr;
    }
    long wr_data() {
        return top->dbus_wr_data;
    }
    long rd_data() {
        return top->dbus_rd_data;
    }

    void set_rd_data(long data) {
        top->dbus_rd_data = data;
    }

    void set_clock(int val) {
        top->clk = val;
    }

    int get_clock() {
        return top->clk;
    }

    void eval_sim(int interval = 0) {
        /* the flow is to wait some time then check signals.
        i.e. wait then eval. On previous eval it already switched clk phase,
        so dont need to switch again before wait.
        */
        if (Verilated::gotFinish()) return;
        if (interval > CLK_PHASE) {
            printf("ERROR: interval can not exceed clock phase! Skipping\n");
            return;
        }
        timestamp += interval;
        if (interval && (timestamp % CLK_PHASE == 0)) top->clk = !top->clk;
        top->eval();
        if (vcd) vcd->dump(timestamp);
    }

    void wait_ticks(int repeats = 1) {
        while (repeats--) wait(CLK_PHASE * 2);
    }

    void wait(int interval = CLK_PHASE) {
        /* if interval bigger then delta then first wait delta until clock edge
        then wait the rest of interval
        */
        int delta = CLK_PHASE - timestamp % CLK_PHASE; // remaining time until next phase
        if (delta && interval > delta) {
            eval_sim(delta);
            interval -= delta;
        }
        int cycles = interval / CLK_PHASE;
        if (cycles) {
            for (int i = 0; i < cycles; i++) {
                eval_sim(CLK_PHASE);
                interval -= CLK_PHASE;
            }
            if (!interval) return;
        }
        eval_sim(interval);
    }

    void reset(int repeats = 1) {
        set_rd_data(0);
        top->res_n = 0;
        wait(CLK_PHASE * 2 * repeats);
        top->res_n = 1;
        wait(0);
        printf("[%lu] INFO: --- RESET DONE ---\n", timestamp);
    }

    /** Upload hex mem file into instrucion ROM
     * 
     * @param mem_file_path mem file string
     */
    void boot_load(const char *mem_file_path = "test.mem") {
        svSetScope(svGetScopeFromName("TOP.riscv.instruction_mem"));
        Vriscv::initmem(mem_file_path);
    }

    /** Upload hex mem file into data memory
     * 
     * @param mem_file_path mem file string
     */
    void prefill_data_memory(const char *mem_file_path = "prefill.mem", int word_len = XLEN / 8) {
        svSetScope(svGetScopeFromName("TOP.riscv.data_mem"));
        Vriscv::initmem(mem_file_path);
    }

    /** Check if address is in data mememory address range
     * 
     * @return 1 if address is in dmem range, 0 otherwise
     */
    int is_data_memory_address() {
        return addr() >= DATA_MEMORY_BASE_ADDR && addr() < DATA_MEMORY_LAST_ADDR;
    }

    /** Can define additional stop condition, for example if instruction is zero cmd
     * 
     * @return 1 if condition occurred, 0 otherwise
     */
    int stop_event() {
        return top->rootp->riscv__DOT__core__DOT__pc &&
        !top->rootp->riscv__DOT__core__DOT__instruction;
    }
    
    void dump(int std_out = 0) {
        if (std_out) {
            /*
            if (addr() >= DATA_MEMORY_BASE_ADDR && addr() < DATA_MEMORY_LAST_ADDR) {
                printf("DMEM DUMP: ");
                for (int i = 0; i < 4; i++) {
                    try {
                        printf("%d ", top->rootp->riscv__DOT__data_mem__DOT__MEMX[addr()][i]);
                    } catch (...) {
                        printf("Error dumping dmem address %d\n", addr() + i);
                    }
                }
            }
            */
            printf("[%lu] DEBUG: FETCH: imem_req=%d  imem_addr=%08x  instruction=%08x  imem_req=%d  next_pc=%08x\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__imem_req,
                top->rootp->riscv__DOT__core__DOT__pc,
                top->rootp->riscv__DOT__core__DOT__instruction,
                top->rootp->riscv__DOT__core__DOT__imem_req,
                top->rootp->riscv__DOT__core__DOT__next_pc
            );
            printf("[%lu] DEBUG: CORE:  opcode=%02x  funct3=%d  rf_wr_data_sel=%d  rd_addr=%08x  rs1_addr=%08x  rs1_data=%08x  rs2_addr=%08x  rs2_data=%08x  imm=%08x\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__opcode,
                top->rootp->riscv__DOT__core__DOT__funct3,
                top->rootp->riscv__DOT__core__DOT__rf_wr_data_sel,
                top->rootp->riscv__DOT__core__DOT__rd_addr,
                top->rootp->riscv__DOT__core__DOT__rs1_addr,
                top->rootp->riscv__DOT__core__DOT__rs1_data,
                top->rootp->riscv__DOT__core__DOT__rs2_addr,
                top->rootp->riscv__DOT__core__DOT__rs2_data,
                top->rootp->riscv__DOT__core__DOT__immediate
            );
            printf("[%lu] DEBUG: ALU:  opcode=%02x  alu_a=%d  alu_b=%08x  alu_res=%08x\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__alu_op,
                top->rootp->riscv__DOT__core__DOT__alu_a,
                top->rootp->riscv__DOT__core__DOT__alu_b,
                top->rootp->riscv__DOT__core__DOT__alu_res
            );
            printf("[%lu] DEBUG: BUS:  addr=%08x  dmem_req=%d  dmem_wr=%d  wr_data=%08x  rd_data=%08x\n\n",
                timestamp,
                top->dmem_addr,
                top->dmem_req,
                top->dmem_wr,
                top->dbus_wr_data,
                top->dbus_rd_data
            );
        } else {
            fprintf(logger->fptr, "[%lu] DEBUG: CORE: pc=%08x  next_pc=%08x  inst=%08x  opcode=0x%0x  funct3=%d  imm=%08x  alu_a=%lx  alu_b=%lx  alu_res=%lx  brunch_lt=%d  brunch_ltu=%d\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__pc,
                top->rootp->riscv__DOT__core__DOT__next_pc,
                top->rootp->riscv__DOT__core__DOT__instruction,
                top->rootp->riscv__DOT__core__DOT__opcode,
                top->rootp->riscv__DOT__core__DOT__funct3,
                top->rootp->riscv__DOT__core__DOT__immediate,
                top->rootp->riscv__DOT__core__DOT__alu_a,
                top->rootp->riscv__DOT__core__DOT__alu_b,
                top->rootp->riscv__DOT__core__DOT__alu_block__DOT__alu_res,
                top->rootp->riscv__DOT__core__DOT__branch_block__DOT__lt,
                top->rootp->riscv__DOT__core__DOT__branch_block__DOT__ltu
            );
            fprintf(logger->fptr, "[%lu] DEBUG: IRQ: imem_req=%d  irq_en=%d  irq_start=%d  irq_stop=%d  irq_fault=%d  illegal_dec=%d  irq_align=%d  irq_timer=%d  irq_software=%d  irq_external=%d  irq_ecall=%d  irq_break=%d  illegal_csr=%d  irq_illegal_ack=%d irq_illegal=%d  csr_data_out=%x\n",
                timestamp,
                
                top->rootp->riscv__DOT__core__DOT__imem_req,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_en,
                top->rootp->riscv__DOT__core__DOT__irq_start,
                top->rootp->riscv__DOT__core__DOT__irq_stop,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_fault,
                top->rootp->riscv__DOT__core__DOT__illegal_dec,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_align,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_timer,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_software,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_external,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_ecall,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_break,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__illegal,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_illegal_ack,
                top->rootp->riscv__DOT__core__DOT__csr_block__DOT__irq_illegal,
                top->rootp->riscv__DOT__core__DOT__csr_data_out
            );
            fprintf(logger->fptr, "[%lu] DEBUG: REGFILE: rf_wr_data_sel=%d  rd_addr=%x  rs1_addr=%x  rs2_addr=%x  rs1_data=%lx  rs2_data=%lx  rf_wr_data=%lx\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__rf_wr_data_sel,
                top->rootp->riscv__DOT__core__DOT__rd_addr,
                top->rootp->riscv__DOT__core__DOT__rs1_addr,
                top->rootp->riscv__DOT__core__DOT__rs2_addr,
                top->rootp->riscv__DOT__core__DOT__rs1_data,
                top->rootp->riscv__DOT__core__DOT__rs2_data,
                top->rootp->riscv__DOT__rf_wr_data
            );
            fprintf(logger->fptr, "[%lu] DEBUG: DATABUS: dmem_req=%d  dmem_wr=%d  addr=%08x  wr_data=%08x  rd_data=%08x\n\n",
                timestamp,
                top->dmem_req,
                top->dmem_wr,
                top->dmem_addr,
                top->dbus_wr_data,
                top->dbus_rd_data
            );
            /*
            fprintf(logger->fptr, "DUMP REGFILE: ");
            for (int i = 0; i < 32; i++) {
                try {
                    fprintf(logger->fptr, "[%d]%lx ", i, top->rootp->riscv__DOT__reg_file__DOT__reg_mem[i]);
                } catch (...) {
                    fprintf(logger->fptr, "Error dumping array index %d\n", i);
                }
            }
            fprintf(logger->fptr, "\n");*/
        }
    }

    void dump_regfile() {
        printf("DUMP REGFILE:\n");
        for (int i = 0; i < 32; i++) {
            try {
                printf("[%d]%lx ", i, top->rootp->riscv__DOT__reg_file__DOT__reg_mem[i]);
                if ((i && !(i % 8)) || i == 31) printf("\n");
            } catch (...) {
                printf("Error dumping array index %d\n", i);
            }
        }
    }
};
