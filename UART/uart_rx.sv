/*
    UART Receiver
*/
//`define DEBUG 1
`include "regmap.vh"


module uart_rx #(parameter DATA_WIDTH = 8, parameter TICKS_NUM = 16) (
    input clk,
    input res_n,
    input rx_baud,
    input rx_din,
    input [DATA_WIDTH-1:0] lcreg,
    output logic [DATA_WIDTH+1:0] rx_out,
    output logic rx_ready
);
    localparam TICK_BW = $clog2(TICKS_NUM)-1;
    localparam TICK_DELTA = TICKS_NUM > 8 ? 2 : 1;
    localparam TICK_SAMPLE_A = TICKS_NUM / 2 - TICK_DELTA;
    localparam TICK_SAMPLE_B = TICKS_NUM / 2;
    localparam TICK_SAMPLE_C = TICKS_NUM / 2 + TICK_DELTA;
    localparam TICK_SAMPLE_D = TICK_SAMPLE_C + 1;

    typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP } op_states;
    op_states state, next_state;

    logic sreg_en;
    logic parity_val;
    logic parity_bit;
    logic first_tick;
    logic last_tick;
    logic init_ct;
    logic cb_incr;
    logic voted_din;
    logic rx_done;
    logic rx_done_set;
    logic ct_restart;
    logic [TICK_BW:0] count_ticks, ct_nextval;
    logic [$clog2(DATA_WIDTH)-1:0] count_bits, cb_next;
    logic [DATA_WIDTH:0] sreg_out;
    logic [2:0] parity_reg;
    logic last_bit;
    logic err_par, err_fr;

    // pushing also parity bit
    shift_reg #(.N(DATA_WIDTH+1)) rsr (
        .clk(first_tick),
        .res_n(res_n),
        .en(sreg_en),
        .din(voted_din),
        .dout(sreg_out),
        .load_en(),
        .load(),
        .dout_n()
    );

    // Same as tx_ready in Tx. rx_done width is baud width, but fifo needs clk width
    always_ff @(posedge clk) rx_done_set <= rx_done;
    always_ff @(posedge clk) rx_ready <= rx_done & ~rx_done_set;

    // 3-stage synchronizer to prevent metastability and glitches shorter than system clock
    logic [2:0] rx_sync_reg;
    logic s0, s1, s2;
    logic rx_sync;
    assign rx_sync = rx_sync_reg[2];
    always_ff @(posedge clk or negedge res_n) begin
        if (~res_n)
            rx_sync_reg <= 3'b111;
        else
            rx_sync_reg <= {rx_sync_reg[1:0], rx_din};
    end
    // Majority voting for each bit, at least 2 samples with same value needed
    // For 32 ticks need more samples?
    always_ff @(posedge rx_baud) begin
        if (count_ticks == TICK_SAMPLE_A) s0 <= rx_sync;
        if (count_ticks == TICK_SAMPLE_B) s1 <= rx_sync;
        if (count_ticks == TICK_SAMPLE_C) s2 <= rx_sync;
    end
    assign voted_din = (s0 & s1) | (s0 & s2) | (s1 & s2);

    /*
    Count ticks always, except if reset or rx_sync
    becomes 0 in idle state. On next tick count is 0
    and last tick is 1 and state moves to START.
    So Rx will be behind Tx by 1 tick.
    count_ticks should be 0 during 1 tick only.
    */
    assign first_tick = ~|count_ticks;
    assign last_tick = &count_ticks;
    assign ct_nextval = count_ticks + 1;
    assign ct_restart = init_ct & |count_ticks;

    always_ff @(posedge rx_baud or negedge res_n) begin
        if (~res_n)
            count_ticks <= 0;
        else if (ct_restart)
            count_ticks <= 0;
        else
            count_ticks <= ct_nextval;
    end

    always_ff @(posedge rx_baud) begin
        if (state == IDLE & ~rx_sync)
            init_ct <= 1'b1;
        else
            init_ct <= 1'b0;
    end

    // count bits only on DATA and STOP states
    assign last_bit = count_bits[2] & count_bits[1:0] == lcreg[`UART_LCR_WLS];    // 4 to 7
    assign cb_next = count_bits + cb_incr;
    always_ff @(posedge first_tick) begin
        if (~cb_incr)
            count_bits <= 0;
        else
            count_bits <= cb_next;
    end

    // for even data width better to set even parity
    // so if external peripheral reset occurs and device sends 0xFF we know if it's valid or not
    assign parity_reg = lcreg[`UART_LCR_PS];

    // Even Parity: parity bit is set to 1 if the number of 1s in the data frame is odd making the total count even
    // Odd  Parity: parity bit is set to 1 if the number of 1s in the data frame is even making the total count odd
    // alternative is to move the parity and stop bit checks to upper level
    // and check them when cpu makes a read
    // Same as: assign parity_bit = ^parity_reg[2:1];
    always_comb begin
        case ({parity_reg[2:1]})
            2'b00: parity_bit = 1'b0;
            2'b01: parity_bit = 1'b1;
            2'b10: parity_bit = 1'b1;
            2'b11: parity_bit = 1'b0;
        endcase
    end

    always_comb begin
        case (lcreg[`UART_LCR_WLS])
            2'b00: parity_val = ^sreg_out[5:0];
            2'b01: parity_val = ^sreg_out[6:0];
            2'b10: parity_val = ^sreg_out[7:0];
            2'b11: parity_val = ^sreg_out[8:0];
        endcase
    end

    // Error flags
    assign err_par = parity_reg[0] & (parity_val ^ parity_bit);
    assign err_fr = state == STOP && ~voted_din;
    
    // Apply output. For 5, 6 and 7 bit words padding zeros. While msb in sreg is parity.
    always_comb begin
        case (lcreg[`UART_LCR_WLS])
            2'b00: rx_out = {err_fr, err_par, 2'b0, sreg_out[5:0]};
            2'b01: rx_out = {err_fr, err_par, 1'b0, sreg_out[6:0]};
            2'b10: rx_out = {err_fr, err_par, sreg_out[7:0]};
            2'b11: rx_out = {err_fr, err_par, sreg_out[7:0]};
        endcase
    end

    // Demux
    always_comb begin
        case (state)
            START: begin
                cb_incr = 1'b0;
                sreg_en = 1'b0;
            end
            DATA: begin
                cb_incr = 1'b1;
                sreg_en = 1'b1;
            end
            PARITY: begin
                cb_incr = 1'b0;
                sreg_en = 1'b1;
            end
            STOP: begin
                cb_incr = 1'b1;
                sreg_en = 1'b0;
                if (count_ticks == TICK_SAMPLE_D)
                    rx_done = 1'b1; // starting from this tick rx_out is settled
                else
                    rx_done = 1'b0; // one tick length is enough for rx_done to be 1
            end
            default: begin
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = 1'b0;
            end
        endcase
    end

    // FSM logic
    always_latch begin
        case (state)
            START: begin
                if (voted_din == 1'b0)
                    next_state = DATA;
                else
                    next_state = IDLE;
            end
            DATA: begin
                if (last_bit) begin
                    if (parity_reg[0])
                        next_state = PARITY;
                    else
                        next_state = STOP;
                end
            end
            PARITY: next_state = STOP;
            STOP: next_state = IDLE;
            default: begin
                if (init_ct)
                    next_state = START;
                else
                    next_state = IDLE;
            end
        endcase
    end
    always_ff @(posedge first_tick or negedge res_n) begin
        if (~res_n)
            state <= IDLE;
        else
            state <= next_state;
        `ifdef DEBUG_RUN
            $strobe("DEBUG: [Rx_uart] rx_sync=%0b rx_din=%0b rx_out=%0b count_bits=%0d", rx_sync, rx_din, rx_out, count_bits);
        `endif
    end
endmodule
