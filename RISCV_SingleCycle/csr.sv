/*
https://docs.riscv.org/reference/isa/priv/priv-csrs.html

For now only Machine mode.

MIE bits - page 46
See page 48 Table 7. Conditions determining whether a CSR instruction reads or writes the specified CSR.

if csr_req is 1 then:
- csr is ok to be read and written
- rf_wr_data is csr_out
- irc should not read mie csr
*/


module csr #(parameter XLEN = RISCV_XLEN) (
    input logic clk,
    input logic res,
    input logic irq_start,
    input logic irq_sw_pending,
    input logic y_type,
    input logic c_type,
    input logic [2:0] funct3,
    input logic [4:0] sys_rs1,
    input logic [4:0] sys_rd,
    input logic [11:0] sys_imm,
    input logic [31:0] pc,
    input logic [XLEN-1:0] rs1_data,
    input logic [XLEN-1:0] csr_din,
    input logic [XLEN-1:0] mcause_data,     // from irq controller

    output logic illegal,
    output logic irq_ecall,
    output logic irq_break,
    output logic irq_stop,                  // got xret, interrupt handler finished
    output logic [XLEN-1:0] mstatus,        // to irq controller
    output logic [XLEN-1:0] csr_out
);
    logic [XLEN-1:0] csr_val;
    logic [XLEN-1:0] rs_data;
    logic [XLEN-1:0] mie;
    logic [XLEN-1:0] mip;
    logic [XLEN-1:0] mtvec;
    logic [XLEN-1:0] mscratch;
    logic [XLEN-1:0] mepc;
    logic [XLEN-1:0] mcause;
    //logic [XLEN-1:0] mstatus;
    //logic [XLEN-1:0] msip;
    logic rd_ok;
    logic rs_ok;
    logic wr_en;
    logic rd_en;

    assign rd_ok = |sys_rd;
    assign rs_ok = |sys_rs1;

    // if rd is 0 then dont read, if rs1 is 0 then dont write
    assign wr_en = c_type & rs_ok;
    assign rd_en = c_type & rd_ok;

    // Read CSR mux. No read if rd is x0 or funct3 is 0
    // irq started - set mtvec, irq finished - set mepc, else set mie
    // if csr cmd is recieved then csr_out will be the value of csr
    // else always MIE, so irc can poll this reg
    assign csr_out = {{(XLEN-5){1'b0}}, csr_val};
    always_comb begin
        csr_val = mie;
        irq_stop = 1'b0;
        irq_ecall = 1'b0;
        irq_break = 1'b0;
        illegal = 1'b0;

        if (irq_start) begin
            csr_val = mtvec;
        end
        else if (y_type) begin: system_commands
            case (sys_imm)
                IMM_ECALL: begin    // ECALL triggers an exception, redirecting the PC to the trap handler in mtvec
                    irq_ecall = 1'b1;
                    csr_val = mepc;
                end
                IMM_EBREAK: begin   // EBREAK irq_breaks program execution or pauses to enter a debugging environment.
                    irq_break = 1'b1;
                end
                IMM_SRET,
                IMM_MRET,
                IMM_MNRET: begin
                    csr_val = mepc;
                    irq_stop = 1'b1;
                end
                IMM_WFI: begin      //WFI is just a NOP
                end
                // Zawrs:
                IMM_WRS_NTO: begin  // WRS.NTO. cause the hart to temporarily stall execution in a low-power state
                end
                IMM_WRS_STO: begin
                end
                default: illegal = 1'b1;
            endcase
        end
        else if (c_type) begin: zicsr
            case (sys_imm)
                CSR_MIP:        if (rd_en) csr_val = mip;
                CSR_MIE:        if (rd_en) csr_val = mie;
                CSR_MTVEC:      if (rd_en) csr_val = mtvec;
                CSR_MSCRACTH:   if (rd_en) csr_val = mscratch;
                CSR_MEPC:       if (rd_en) csr_val = mepc;
                CSR_MCAUSE:     if (rd_en) csr_val = mcause;
                CSR_MSTATUS:    if (rd_en) csr_val = mstatus;
                default:        illegal = 1'b1;
            endcase
        end
    end


    // Write CSRs; on negedge with stable values
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mepc <= 0;
        else if (irq_start)
            mepc <= pc;
        else if (wr_en & sys_imm === CSR_MEPC)
            mepc <= csr_din;
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mie <= 0;
        else if (wr_en & sys_imm === CSR_MIE)
            mie <= csr_din;
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mtvec <= {TRAP_ADDRESS, 2'b0};
        else if (wr_en & sys_imm === CSR_MTVEC)
            mtvec <= csr_din;
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mscratch <= 0;
        else if (wr_en & sys_imm === CSR_MSCRACTH)
            mscratch <= csr_din;
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mcause <= 0;
        else if (irq_start)
            mcause <= mcause_data;
        else if (wr_en & sys_imm === CSR_MCAUSE)
            mcause <= csr_din;
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mstatus <= 0;
        else if (wr_en & sys_imm === CSR_MSTATUS)
            mstatus <= csr_din;
        else if (irq_start)     // save mie to mpie and disable mie
            mstatus <= {mstatus[XLEN-1:8], mstatus[3], mstatus[6:4], 1'b0, mstatus[2:0]};
        else if (irq_stop)     // Restore mstatus.mpie to mstatus.mie
            mstatus <= {mstatus[XLEN-1:8], 1'b0, mstatus[6:4], mstatus[7], mstatus[2:0]};
    end
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mip <= 0;
        else if (irq_start & ~irq_sw_pending)
            mip <= {csr_din[XLEN-1:12], 1'b1, csr_din[10:0]}; // MEIP 11
        else if (irq_start & irq_sw_pending)
            mip <= {csr_din[XLEN-1:4], 1'b1, csr_din[2:0]}; // MSIP 3
        else if (irq_stop & ~irq_sw_pending)
            mip <= {csr_din[XLEN-1:12], 1'b0, csr_din[10:0]}; // MEIP 11
        else if (irq_stop & irq_sw_pending)
            mip <= {csr_din[XLEN-1:4], 1'b0, csr_din[2:0]}; // MSIP 3
        else if (wr_en & sys_imm === CSR_MIP)
            mip <= {csr_din[XLEN-1:12], mip[11], csr_din[10:8], mip[7], csr_din[6:0]};  // MTIP and MEIP are Read only
    end

    /* this logic is done by core:
    // write = 1, set = 2, clear = 3
    assign rs_data = funct3[2] ? {{(XLEN-5){1'b0}}, sys_rs1} : rs1_data;
    always_comb begin
        case (funct3[1:0])
            OP_FUNCT3_CSRRS:   csr_din = rs_data | csr_val;     // rd = csr, csr = csr | rs1. alua=rs1 or sysrs1 .alub=csr_out or 0x0
            OP_FUNCT3_CSRRC:   csr_din = rs_data & ~csr_val;    // rd = csr, csr = csr & ~rs1
            default:           csr_din = rs_data | 0x0;         // rd = csr, csr = rs1 (OP_FUNCT3_CSRRW)
        endcase
    end
    */
endmodule
