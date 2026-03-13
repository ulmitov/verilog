/*
    UART Receiver
*/
//`define DEBUG 1

module uart_rx #(parameter DATA_WIDTH = 8, parameter TICKS_NUM = 16) (
    input clk,
    input res_n,
    input rx_baud,
    input rx_din,
    output logic [DATA_WIDTH-1:0] rx_out,
    output logic rx_ready,
    output logic err_par,   // parity error
    output logic err_fr     // framing error (invalid stop bit)
);
    localparam TICK_BW = $clog2(TICKS_NUM)-1;
    localparam TICK_DELTA = TICKS_NUM > 8 ? 2 : 1;
    localparam TICK_SAMPLE_A = TICKS_NUM / 2 - TICK_DELTA;
    localparam TICK_SAMPLE_B = TICKS_NUM / 2;
    localparam TICK_SAMPLE_C = TICKS_NUM / 2 + TICK_DELTA;

    typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP } op_states;
    op_states state, next_state;

    logic sreg_en;
    logic parity;
    logic parity_bit;
    logic first_tick;
    logic init_ct;
    logic cb_incr;
    logic voted_din;
    logic rx_done;
    logic rx_done_set;
    logic ct_restart;
    logic [TICK_BW:0] count_ticks, ct_nextval;
    logic [$clog2(DATA_WIDTH)-1:0] count_bits, cb_next;
    logic [2:0] PARITY_REG;

    shift_reg #(.N(DATA_WIDTH)) rx_reg (
        .clk(first_tick),
        .res_n(res_n),
        .en(sreg_en),
        .din(voted_din),
        .dout(rx_out),
        .load_en(),
        .load(),
        .dout_n()
    );

    // Same as tx_ready in Tx. rx_done width is baud width, but fifo needs clk width
    always_ff@(posedge clk) rx_done_set <= rx_done;
    always_ff@(posedge clk) rx_ready <= rx_done & ~rx_done_set;

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
    // For 16 or 32 ticks need more samples?
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
    assign ct_nextval = count_ticks + 1;
    assign ct_restart = init_ct & |count_ticks;
    always_ff @(posedge rx_baud or negedge res_n) begin
        if (~res_n | ct_restart)
            count_ticks <= 0;
        else
            count_ticks <= ct_nextval;
    end
    // can remove negedge rx_sync here but it will slighlty slower the rate
    always_ff @(posedge rx_baud or negedge rx_sync) begin
        if (state == IDLE & ~rx_sync)
            init_ct <= 1'b1;
        else
            init_ct <= 1'b0;
    end

    // count bits only on DATA and STOP states
    assign cb_next = count_bits + cb_incr;
    always_ff @(posedge first_tick) begin
        if (~cb_incr)
            count_bits <= 0;
        else
            count_bits <= cb_next;
    end

    // parity bit. for even data width better to set even parity
    // so if external peripheral reset occurs and device sends 0XFF we know if it's valid or not
    assign parity = ^rx_out;
    assign PARITY_REG = 3;
    always_comb begin
        case ({PARITY_REG[2:1]})
            2'b00: parity_bit = ~parity;
            2'b01: parity_bit = parity;
            2'b10: parity_bit = 1'b1;
            2'b11: parity_bit = 1'b0;
        endcase
    end

    // Error flags
    always_ff @(posedge first_tick) begin
        if (state == PARITY && voted_din != parity_bit)
            err_par <= 1'b1;
        else
            err_par <= 1'b0;

        if (state == STOP && voted_din != 1'b1)
            err_fr <= 1'b1;
        else
            err_fr <= 1'b0;
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
                sreg_en = 1'b0;
            end
            STOP: begin
                cb_incr = 1'b1;
                sreg_en = 1'b0;
                rx_done = 1'b1;
            end
            default: begin
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = 1'b0;
            end
        endcase
    end

    // FSM logic
    always_comb begin
        case (state)
            START: begin
                if (voted_din == 1'b0)
                    next_state = DATA;
                else
                    next_state = IDLE;
            end
            DATA: begin
                if (&count_bits) begin
                    if (PARITY_REG[0])
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
        `ifdef DEBUG
            $strobe("DEBUG: [Rx_uart] rx_sync=%0b rx_din=%0b rx_out=%0b count_bits=%0d", rx_sync, rx_din, rx_out, count_bits);
        `endif
    end
endmodule
