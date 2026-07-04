/*
    UART Receiver
*/
//`define DEBUG 1
`include "regmap.vh"


module uart_rx #(parameter DATA_WIDTH = 8, parameter TICKS_NUM = 16) (
    input res_n,
    input rx_baud,
    input rx_din,
    input [DATA_WIDTH-1:0] lcreg,
    output logic [DATA_WIDTH+1:0] rx_out,
    output logic rx_done
);
    localparam TICK_BW = $clog2(TICKS_NUM);
    localparam TICK_DELTA = TICKS_NUM > 8 ? 2 : 1;
    localparam TICK_SAMPLE_A = TICKS_NUM / 2 - TICK_DELTA;
    localparam TICK_SAMPLE_B = TICKS_NUM / 2;
    localparam TICK_SAMPLE_C = TICKS_NUM / 2 + TICK_DELTA;
    localparam TICK_SAMPLE_D = TICK_SAMPLE_C + 1;

    typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP } op_states;
    op_states rx_fsm, next_rx_fsm;

    logic sreg_en;
    logic parity_val;
    logic parity_bit;
    logic first_tick;
    logic last_tick;
    logic init_ct;
    logic cb_incr;
    logic voted_din;
    logic last_bit;
    logic err_p;
    logic err_f;
    logic pen;
    logic [TICK_BW-1:0] count_ticks;
    logic [TICK_BW-1:0] ct_nextval;
    logic [$clog2(DATA_WIDTH)-1:0] count_bits;
    logic [$clog2(DATA_WIDTH)-1:0] cb_next;
    logic [DATA_WIDTH-1:0] sout;
    logic [DATA_WIDTH-1:0] rsr_data;


    shift_reg #(.N(DATA_WIDTH)) rsr (
        .clk(last_tick),
        .res_n(res_n),
        .en(sreg_en),
        .din(voted_din),
        .dout(rsr_data),
        .load_en(),
        .load(),
        .dout_n()
    );

    // Majority voting for each bit, at least 2 samples with same value needed
    // For 32 ticks need more samples?
    logic s0, s1, s2;
    always_ff @(posedge rx_baud) begin
        if (count_ticks == TICK_SAMPLE_A) s0 <= rx_din;
        if (count_ticks == TICK_SAMPLE_B) s1 <= rx_din;
        if (count_ticks == TICK_SAMPLE_C) s2 <= rx_din;
    end
    assign voted_din = (s0 & s1) | (s0 & s2) | (s1 & s2);

    /*
    Count ticks always, except if reset or IDLE.
    On next tick count is 0 and rx_fsm moves to START.
    So Rx will be behind Tx by 1 tick.
    */
    assign first_tick = ~|count_ticks;
    assign last_tick = &count_ticks;
    assign ct_nextval = count_ticks + init_ct;

    always_ff @(posedge rx_baud or negedge res_n) begin
        if (~res_n | ~init_ct)
            count_ticks <= {TICK_BW{1'b1}};
        else
            count_ticks <= ct_nextval;
    end

    // count bits only in DATA rx_fsm
    assign last_bit = count_bits[2] & count_bits[1:0] == lcreg[`UART_LCR_WLS +: 2];    // 4 to 7
    assign cb_next = count_bits + cb_incr;
    always_ff @(posedge first_tick) begin
        if (~cb_incr)
            count_bits <= 0;
        else
            count_bits <= cb_next;
    end

    // for even data width better to set even parity
    // so if external peripheral reset occurs and device sends 0xFF we know if it's valid or not
    // Even Parity: parity bit is set to 1 if the number of 1s in the data frame is odd making the total count even
    // Odd  Parity: parity bit is set to 1 if the number of 1s in the data frame is even making the total count odd
    // alternative is to move the parity and stop bit checks to upper level
    // and check them when cpu makes a read. But corner case is if os changes parity settings after data received.
    // So must store parity error flag in the rx fifo anyway.
    always_comb begin
        case ({lcreg[`UART_LCR_SP], lcreg[`UART_LCR_EPS]})
            2'b00: parity_val = ~(^sout);   // odd parity
            2'b01: parity_val = ^sout;   // even parity
            2'b10: parity_val = 1'b1;   // stick 1 parity
            2'b11: parity_val = 1'b0;   // stick 0 parity
        endcase
    end
    /*
    always_comb begin
        if (lcreg[`UART_LCR_SP])
            parity_val = ~lcreg[`UART_LCR_EPS];
        else
            parity_val = lcreg[`UART_LCR_EPS] ~^ ^sout;
    end
    */

    // store parity bit. also can use SR latch in parity rx_fsm.
    always_latch if (rx_fsm == PARITY) parity_bit = voted_din;
    /*
    always_ff @(posedge last_tick) begin
        if (~res_n)
            parity_bit <= 0;
        else if (rx_fsm == PARITY)
            parity_bit <= voted_din;
    end*/

    // Error flags
    assign pen = lcreg[`UART_LCR_PEN];
    assign err_f = rx_fsm == STOP & ~voted_din;  // when rx_ready is 1, voted_din is the stop bit. (rx_fsm == STOP is not needed actually)
    assign err_p = pen & (parity_val ^ parity_bit);
    assign rx_out = {err_f, err_p, sout};

    always_comb begin
        case (lcreg[`UART_LCR_WLS +: 2])
            2'b00: sout = {3'b0, rsr_data[7:3]};
            2'b01: sout = {2'b0, rsr_data[7:2]};
            2'b10: sout = {1'b0, rsr_data[7:1]};
            2'b11: sout = rsr_data[7:0];
        endcase
    end

    // Demux
    always_comb begin
        case (rx_fsm)
            START: begin
                init_ct = 1'b1;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = 1'b0;
            end
            DATA: begin
                init_ct = 1'b1;
                cb_incr = 1'b1;
                sreg_en = 1'b1;
                rx_done = 1'b0;
            end
            PARITY: begin
                init_ct = 1'b1;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = 1'b0;
            end
            STOP: begin
                init_ct = 1'b1;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = count_ticks == TICK_SAMPLE_D; // starting from TICK_SAMPLE_C rx_out is settled
            end
            default: begin
                init_ct = ~rx_din;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                rx_done = 1'b0;
            end
        endcase
    end

    // FSM logic
    always_latch begin
        case (rx_fsm)
            START: begin
                if (voted_din == 1'b0)
                    next_rx_fsm = DATA;
                else
                    next_rx_fsm = IDLE;
            end
            DATA: begin
                if (last_bit) begin
                    if (pen)
                        next_rx_fsm = PARITY;
                    else
                        next_rx_fsm = STOP;
                end
            end
            PARITY: next_rx_fsm = STOP;
            STOP: begin
                if (rx_din === 0)
                    next_rx_fsm = START;    // just before first tick rx_din will be 0
                else
                    next_rx_fsm = IDLE;
            end
            default: begin
                if (rx_din === 0)
                    next_rx_fsm = START;
                else
                    next_rx_fsm = IDLE;
            end
        endcase
    end
    always_ff @(posedge first_tick or negedge res_n) begin
        if (~res_n)
            rx_fsm <= IDLE;
        else
            rx_fsm <= next_rx_fsm;
        `ifdef DEBUG_RUN
            $strobe("DEBUG: [uart_rx] rx_din=%0b rx_out=%0b count_bits=%0d", rx_din, rx_out, count_bits);
        `endif
    end
endmodule
