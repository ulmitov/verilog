import risc_pkg::*;


module clint #(parameter XLEN = 32) (
    input logic clk,
    input logic res,
    input logic wr_en,
    input logic [XLEN-1:0] irq_external,    // from peripherals
    input logic [XLEN-1:0] data_in,
    input logic [31:0] data_addr,

    output logic irq_sw_pending,
    output logic irq_ex_pending,
    output logic irq_timer_pending
);
    logic [XLEN-1:0] msip;
    logic [XLEN-1:0] mtime;
    logic [XLEN-1:0] mtimecmp;
    logic [$clog2(XLEN)-1:0] cnt;
    logic irq_mmode_en;

    assign irq_sw_pending       = msip[0];
    assign irq_ex_pending       = irq_external[cnt];
    assign irq_timer_pending    = mtimecmp >= mtime;
    assign irq_mmode_en         = ~irq_sw_pending & ~irq_ex_pending & ~irq_timer_pending;

    /* CLINT internal memory mapped csrs */
    always_ff @(negedge clk or posedge res) begin
        if (res)
            msip <= 0;
        else if (wr_en && data_addr === CLINT_MSIP)
            msip <= data_in;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mtime <= 0;
        else if (wr_en && data_addr === CLINT_MTIME)
            mtime <= data_in;
    end

    always_ff @(negedge clk or posedge res) begin
        if (res)
            mtimecmp <= 0;
        else if (wr_en && data_addr === CLINT_MTIMECMP)
            mtimecmp <= data_in;
    end

    `ifndef CLINT_EX_IRQ
        assign cnt = 1'b0;
    `else
    generate
        if (`CLINT_EX_IRQ <= 1)
            assign cnt = 1'b0;
        else begin
            counter_tff_sync #($clog2(`CLINT_EX_IRQ)) counter (
                .count_up(1'b1),
                .clk(clk),
                .res_n(~res),
                .en(irq_mmode_en),
                .count(cnt)
            );
        end
    endgenerate
    `endif
endmodule
