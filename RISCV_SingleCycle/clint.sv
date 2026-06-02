/*
An interrupt i will trap to M-mode (causing the privilege mode to change to M-mode) if all of the following
are true: (a) either the current privilege mode is M and the MIE bit in the mstatus register is set, or the
current privilege mode has less privilege than M-mode; (b) bit i is set in both mip and mie ; and (c) if register
mideleg exists, bit i is not set in mideleg .
These conditions for an interrupt trap to occur must be evaluated in a bounded amount of time from when
an interrupt becomes, or ceases to be, pending in mip , and must also be evaluated immediately following
The RISC-V Instruction Set Manual, Volume II | © RISC-V International3.1. Machine-Level CSRs | Page 46
the execution of an xRET instruction or an explicit write to a CSR on which these interrupt trap conditions
expressly depend (including mip , mie , mstatus , and mideleg ).


Machine External Interrupt (MEIP) bit


if mstatus.MIE is on then procced  (global enable)
if MIE.MEIE is on then proceed or MSIE (interrupt specific enable)


System call is exception #8


2.1.4 Standard Entry & Exit Behavior for Interrupt Handlers
Whenever an interrupt occurs, hardware will automatically save and restore important registers.
The following steps are complete as an interrupt handler is entered.
• Save pc to mepc
• Save Privilege level to mstatus.mpp
• Save mstatus.mie to mstatus.mpie
• Set pc to interrupt handler address, based on mode of operation
• Disable interrupts by setting mstatus.mie=0
At this point control is handed over to software where the interrupt processing begins. At the
end of the interrupt handler, the mret instruction will do the following.
• Restore mepc to pc
8
• Restore mstatus.mpp to Priv
• Restore mstatus.mpie to mstatus.mie


    //Each MSIP register is a 32-bit wide WARL register where the upper 31 bits are wired to zero.
    //The least significant bit is reflected in MSIP of the mip CSR. A machine-level software interrupt 
    //for a HART is pending or cleared by writing 1 or 0 respectively to the corresponding MSIP register.
*/
import risc_pkg::*;


module clint #(parameter XLEN = 32) (
    input logic clk,
    input logic res,
    input logic csr_req,                    // from decode block
    input logic irq_stop,                   // from csr block
    input logic mem_req,
    input logic irq_ecall,
    input logic irq_break,
    input logic irq_illegal,
    input logic irq_align,
    input logic irq_fault,
    input logic [XLEN-1:0] mie,             // from csr block
    input logic [XLEN-1:0] irq_external,    // from peripherals
    input logic [XLEN-1:0] data_in,
    input logic [XLEN-1:0] mstatus,
    input logic [31:0] data_addr,
    
    output logic irq_start,
    output logic irq_sw_pending,
    output logic [XLEN-1:0] mcause    // to csr block
);
    logic [$clog2(XLEN)-1:0] cnt;
    logic irq_en;
    logic irq_mmode_en;
    logic irq_mmode_ex_en;
    logic irq_mmode_sw_en;
    logic irq_mmode_tc_en;
    logic irq_ex_pending;
    logic [XLEN-1:0] msip;
    //logic [XLEN-1:0] mtime;
    //logic [XLEN-1:0] mtimecmp;

    assign irq_mmode_en = ~irq_stop & ~csr_req & mstatus[3]; // mstatus.MIE
    assign irq_mmode_ex_en = irq_mmode_en & mie[11];    // mie.MEIE
    assign irq_mmode_sw_en = irq_mmode_en & mie[3];     // mie.MSIE
    assign irq_mmode_tc_en = irq_mmode_en & mie[7];     // mie.MTIE

    assign irq_sw_pending = irq_mmode_sw_en & msip[0];
    assign irq_ex_pending = irq_mmode_ex_en & irq_external[cnt];
    //assign irq_timer_pending = irq_mmode_tc_en & (mtimecmp >= mtime);

    /*
    External Interrupts (Highest priority)
    Software Interrupts
    Timer Interrupts
    Synchronous Exceptions (Lowest priority
    */
    always_comb begin
        if (irq_ex_pending) begin
            irq_en = 1'b1;
            mcause = {1'b1, 27'b0, 4'b1011};
        end else if (irq_sw_pending) begin
            irq_en = 1'b1;
            mcause = {1'b1, 27'b0, 4'b0011};
        //else if (irq_timer_pending) mcause = {1'b1, 28'b0, 3'b111};
        end else if (irq_align) begin
            irq_en = 1'b1;
            mcause = {28'b0, 4'b0000};
        end else if (irq_fault) begin
            irq_en = 1'b1;
            mcause = {28'b0, 4'b0001};
        end else if (irq_illegal) begin
            irq_en = 1'b1;
            mcause = {28'b0, 4'b0010};
        end else if (irq_break) begin
            irq_en = 1'b1;
            mcause = {28'b0, 4'b0011};
        end else if (irq_ecall) begin
            irq_en = 1'b1;
            mcause = {28'b0, 4'b1011};
        end else begin
            irq_en = 0;
            mcause = 0;
        end
    end

    // set irq just for one tick
    always_ff @(negedge clk or posedge res) begin
        if (res)
            irq_start <= 0;
        else
            irq_start <= irq_start ^ irq_en;
    end

    // MSIP: CLINT internal csr
    always_ff @(negedge clk or posedge res) begin
        if (res)
            msip <= 0;
        else if (irq_stop)
            msip <= 0;
        else if (mem_req && data_addr == `CLINT_MSIP)
            msip <= data_in;
        // else: each sw interrup signal from core
    end

    
    `ifndef CLINT_EX_IRQ
        assign cnt = 1'b0;
    `else
    generate
        if (`CLINT_EX_IRQ == 0 | `CLINT_EX_IRQ == 1)
            assign cnt = 1'b0;
        else begin
            counter_tff_sync #($clog2(`CLINT_EX_IRQ)) counter (
                .count_up(1'b1),
                .clk(clk),
                .res_n(~res | ~irq_stop),
                .en(irq_mmode_en),
                .count(cnt)
            );
        end
    endgenerate
    `endif
endmodule
