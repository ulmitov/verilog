#ifndef COMMON_H
#include "common.h"
#endif


class Interface {
public:
    unsigned long timestamp;
    const IData& _req;
    const IData& _wr;
    IData& _addr;
    IData& _wr_data;
    const IData& _rd_data;
    Vriscv___024root *root;  // Root instance pointer to allow access to model internals,
    Vriscv *top;
    VerilatedVcdC* vcd;
    
    Interface(Vriscv *dut, char vcdc = 1):
        timestamp(0),
        vcd(vcdc ? new VerilatedVcdC() : nullptr),
        top(dut),
        _req(dut->dmem_req),
        _wr(dut->dmem_wr),
        _addr(dut->dmem_addr),
        _wr_data(dut->dbus_wr_data),
        _rd_data(dut->dbus_rd_data),
        root(dut->rootp)
    {
        if (vcdc) {
            top->trace(vcd, 99);
            vcd->open("vcd/RISCV_DV.vcd");
        }
    }

    ~Interface() {
        wait_ticks(10);
        printf("[%lu] INFO: End of testbench\n", timestamp);
        top->eval();
        if (vcd) {
            vcd->close();
            delete vcd;
        }
        top->final();
        VerilatedCov::write("cov_riscdv.dat");
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
    long int wr_data() {
        return top->dbus_wr_data;
    }
    long int rd_data() {
        return top->dbus_rd_data;
    }

    void set_rd_data(long int data) {
        if (VERBOSITY) printf("INF: Setting rd_data to 0x%0lx\n", data);
        top->dbus_rd_data = data;
    }

    void print_alias() {
        printf("ITF_ALIAS: addr=%08x  dmem_req=%d  dmem_wr=%d  wr_data=%08x  rd_data=%08x ALU=%d\n\n",
            _addr, _req, _wr, _wr_data, _rd_data, root->riscv__DOT__core__DOT__alu_res
        );
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
        top->res_n = 0;
        wait(CLK_PHASE * 2 * repeats);
        top->res_n = 1;
        wait(0);
        printf("[%lu] INFO: --- RESET DONE ---\n", timestamp);
    }

    void boot_load(const char *mem_file_name = "test.mem") {
        svSetScope(svGetScopeFromName("TOP.riscv.instruction_mem"));
        Vriscv::initmem(mem_file_name);
    }

    void prefill_data_memory(const char *mem_fname = "prefill.mem", int word_len = XLEN / 8) {
        svSetScope(svGetScopeFromName("TOP.riscv.data_mem.mem_block"));
        Vriscv::initmem(mem_fname);
    }
    
    void dump(int full = 0) {
        if (full) {
            /*
            if (addr() >= DATA_MEMORY_BASE_ADDR && addr() < DATA_MEMORY_LAST_ADDR) {
                printf("DMEM DUMP: ");
                for (int i = 0; i < 8; i++) {
                    try {
                        printf("%d ", top->rootp->riscv__DOT__data_mem__DOT__mem_block__DOT__MEMX[addr()+i]);
                    } catch (...) {
                        printf("Error dumping dmem address %d\n", addr() + i);
                    }
                }
            }
            */
            printf("[%lu] DEBUG: FETCH: req=%d  imem_addr=%08x  incr_pc=%d  instruction=%08x  imem_req=%d  pc_mux=%d  next_pc_alu=%08x  next_pc=%08x\n",
                timestamp,
                top->rootp->riscv__DOT__core__DOT__fetch_stage__DOT__req,
                top->rootp->riscv__DOT__core__DOT__fetch_stage__DOT__imem_addr,
                top->rootp->riscv__DOT__core__DOT__fetch_stage__DOT__incr_pc,
                top->rootp->riscv__DOT__core__DOT__instruction,
                top->rootp->riscv__DOT__core__DOT__imem_req,
                top->rootp->riscv__DOT__core__DOT__pc_mux,
                top->rootp->riscv__DOT__core__DOT__next_pc_alu,
                top->rootp->riscv__DOT__core__DOT__fetch_stage__DOT__next_pc
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
            //if (VERBOSITY) {
                printf("[%lu] CORE: pc=%08x  instruction=%08x  opcode=0x%0x  rf_wr_data_sel=%d  rd_addr=%08x  rs1_addr=%08x  rs2_addr=%08x  imm=%08x\n",
                    timestamp,
                    top->rootp->riscv__DOT__core__DOT__fetch_stage__DOT__imem_addr,
                    top->rootp->riscv__DOT__core__DOT__instruction,
                    top->rootp->riscv__DOT__core__DOT__opcode,
                    top->rootp->riscv__DOT__core__DOT__rf_wr_data_sel,
                    top->rootp->riscv__DOT__core__DOT__rd_addr,
                    top->rootp->riscv__DOT__core__DOT__rs1_addr,
                    top->rootp->riscv__DOT__core__DOT__rs2_addr,
                    top->rootp->riscv__DOT__core__DOT__immediate
                );
            //}
            printf("[%lu] DEBUG: DATABUS: addr=%08x  dmem_req=%d  dmem_wr=%d  wr_data=%08x  rd_data=%08x\n\n",
                timestamp,
                top->dmem_addr,
                top->dmem_req,
                top->dmem_wr,
                top->dbus_wr_data,
                top->dbus_rd_data
            );
        }
    }
};
