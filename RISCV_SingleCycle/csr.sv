/* ZiCSR extension. For now only Machine mode.
https://docs.riscv.org/reference/isa/priv/priv-csrs.html
*/
module csr #(parameter XLEN = RISCV_XLEN) (
    input logic clk,
    input logic res,
    input logic y_type,
    input logic c_type,
    input logic rd_ok,
    input logic rs_ok,
    input logic imem_req,
    input logic irq_illegal,
    input logic irq_sw_pending,
    input logic irq_ex_pending,
    input logic irq_timer_pending,
    input logic [11:0] sys_imm,
    input logic [31:0] pc,
    input logic [ILEN-1:0] instruction,
    input logic [XLEN-1:0] csr_din,

    output logic irq_start,
    output logic irq_stop,                  // got xret, interrupt handler finished
    output logic [XLEN-1:0] offset,
    output logic [XLEN-1:0] csr_out
);
    logic [XLEN-1:0] csr_val;
    logic [XLEN-1:0] rs_data;
    logic [XLEN-1:0] mie;
    logic [XLEN-1:0] mip;
    logic [XLEN-1:0] mepc;
    logic [XLEN-1:0] mtvec;
    logic [XLEN-1:0] mscratch;
    logic [XLEN-1:0] mstatus;
    logic [XLEN-1:0] mcause;
    logic [XLEN-1:0] mcause_data;
    logic [XLEN-1:0] mtinst;
    logic wr_en;
    logic rd_en;
    logic irq_en;
    logic illegal;
    logic irq_break;
    logic irq_ecall;
    logic irq_illegal_ack;
    logic irq_mmode_en;
    logic irq_mmode_ex_en;
    logic irq_mmode_sw_en;
    logic irq_mmode_tc_en;
    logic irq_external;
    logic irq_software;
    logic irq_timer;
    logic irq_align;
    logic irq_fault;

    assign csr_out = irq_start ? mtvec : csr_val;
    assign irq_mmode_en = ~irq_stop & mstatus[3];       // mstatus.MIE
    assign irq_mmode_ex_en = irq_mmode_en & mie[11];    // mie.MEIE
    assign irq_mmode_sw_en = irq_mmode_en & mie[3];     // mie.MSIE
    assign irq_mmode_tc_en = irq_mmode_en & mie[7];     // mie.MTIE
    assign irq_software = irq_mmode_sw_en & irq_sw_pending;
    assign irq_external = irq_mmode_ex_en & irq_ex_pending;
    assign irq_timer = irq_mmode_tc_en & irq_timer_pending;
    assign irq_illegal_ack = imem_req & (irq_illegal | illegal);
    assign irq_align = ILEN > 16 ? imem_req & pc[0] & pc[1] : imem_req & pc[0]; //must be 4/2 bytes aligned
    assign irq_fault = imem_req & $isunknown(instruction);

    assign irq_en = irq_external | irq_software | irq_timer | irq_align | 
                    irq_fault | irq_illegal_ack | irq_break | irq_ecall;

    // if rd is 0 then dont read, if rs1 is 0 then dont write
    assign wr_en = c_type & rs_ok;
    assign rd_en = c_type & rd_ok;
    // if interrupt (not exception) and mtvec not in vectored mode then jump to base+offset
    assign offset = (mcause[31] & mtvec[0]) ? {mcause[29:0], 2'b00} : 'h0;

    // Read CSR mux
    // irq started: mtvec; irq finished: mepc; csr read: value of csr
    always_comb begin
        csr_val     = mstatus;
        irq_stop    = 1'b0;
        irq_ecall   = 1'b0;
        irq_break   = 1'b0;
        illegal     = 1'b0;

        if (y_type) begin: system_commands
            case (sys_imm)
                IMM_ECALL: begin    // ECALL triggers an exception
                    irq_ecall = 1'b1;
                end
                IMM_EBREAK: begin   // EBREAK breaks program execution or pauses
                    irq_break = 1'b1;
                end
                IMM_SRET,
                IMM_MRET,
                IMM_MNRET: begin
                    irq_stop = 1'b1;
                    csr_val = mepc;
                end
                IMM_WFI: begin      // (Not implemented)
                end
                // Zawrs:
                //IMM_WRS_STO,
                //IMM_WRS_NTO: begin  // (Not implemented)
                //end
                default: illegal = 1'b1;
            endcase
        end
        else if (c_type) begin: zicsr
            case (sys_imm)
                CSR_MIP:        csr_val = mip;
                CSR_MIE:        csr_val = mie;
                CSR_MEPC:       csr_val = mepc;
                CSR_MTVEC:      csr_val = mtvec;
                CSR_MCAUSE:     csr_val = mcause;
                CSR_MSTATUS:    csr_val = mstatus;
                CSR_MSCRACTH:   csr_val = mscratch;
                CSR_MTINST:     csr_val = mtinst;
                default:        illegal = 1'b1;
            endcase
        end
    end


    /***  set irq_start just for one tick  ***/
    always_ff @(negedge clk or posedge res) begin
        if (res)
            irq_start <= 0;
        else begin
            irq_start <= irq_start ^ (imem_req & irq_en);
            if (irq_en) $display("DEBUG: CSR: irq_en  mcause %0h  inst %0h", mcause_data, instruction);
        end
    end


    /***  Write CSRs on negedge with stable values  ***/

    // MIP: pending interrupts
    always_ff @(negedge clk or posedge res) begin
        if (res)
            mip <= 0;
        else
        if (irq_start & irq_external)
            mip <= {csr_din[XLEN-1:12], 1'b1, csr_din[10:0]};   // MEIP 11
        else
        if (irq_start & irq_software)
            mip <= {csr_din[XLEN-1:4], 1'b1, csr_din[2:0]};     // MSIP 3
        else
        if (irq_stop & irq_external)
            mip <= {csr_din[XLEN-1:12], 1'b0, csr_din[10:0]};   // MEIP 11
        else
        if (irq_stop & irq_software)
            mip <= {csr_din[XLEN-1:4], 1'b0, csr_din[2:0]};     // MSIP 3
        else
        if (wr_en & sys_imm === CSR_MIP)
            mip <= {csr_din[XLEN-1:12], mip[11], csr_din[10:8], mip[7], csr_din[6:0]};  // MTIP and MEIP are Read only
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mstatus <= 0;
        else
        if (irq_start)     // save mie to mpie and disable mie
            mstatus <= {mstatus[XLEN-1:8], mstatus[3], mstatus[6:4], 1'b0, mstatus[2:0]};
        else
        if (irq_stop)     // Restore mstatus.mpie to mstatus.mie
            mstatus <= {mstatus[XLEN-1:8], 1'b0, mstatus[6:4], mstatus[7], mstatus[2:0]};
        else
        if (wr_en & sys_imm === CSR_MSTATUS)
            mstatus <= csr_din;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mepc <= 0;
        else if (irq_start | irq_break | irq_ecall)
            mepc <= pc;
        else if (wr_en & sys_imm === CSR_MEPC)
            mepc <= csr_din;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mtinst <= 0;
        else if (irq_start)
            mtinst <= instruction;
        else if (wr_en & sys_imm === CSR_MTINST)
            mtinst <= csr_din;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mie <= 0;
        else if (wr_en & sys_imm === CSR_MIE)
            mie <= csr_din;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mtvec <= TRAP_BASE_ADDRESS;         // set direct mode and default trap address
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

    /*
    External Interrupts (Highest priority) - using mcause bits 4-27 for counter value
    Software Interrupts
    Timer Interrupts
    Synchronous Exceptions (Lowest priority)
    */
    always_comb begin
        if (irq_external)
            mcause_data = {1'b1, 27'b0 , 4'b1011};
        else
        if (irq_software)
            mcause_data = {1'b1, 27'b0, 4'b0011};
        else
        if (irq_timer)
            mcause_data = {1'b1, 27'b0, 4'b0111};
        else
        if (irq_align)
            mcause_data = {28'b0, 4'b0000};
        else
        if (irq_fault)
            mcause_data = {28'b0, 4'b0001};
        else
        if (irq_illegal_ack)
            mcause_data = {28'b0, 4'b0010};
        else
        if (irq_break)
            mcause_data = {28'b0, 4'b0011};
        else
        if (irq_ecall)
            mcause_data = {28'b0, 4'b1011};
        else
            mcause_data = 0;
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
