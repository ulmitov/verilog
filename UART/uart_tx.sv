/*
    UART Transceiver
*/
`include "regmap.vh"


module uart_tx #(parameter DATA_WIDTH = 8, parameter TICKS_NUM = 16) (
    input res_n,
    input baudout,
    input tx_start,
    input [DATA_WIDTH-1:0] lcreg,
    input [DATA_WIDTH-1:0] tx_din,
    output logic tx_dout,
    output logic tx_ready,
    output logic tsr_empty
);
    localparam TICK_BW = $clog2(TICKS_NUM) - 1;

    typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP, STOP_HALF } op_states;
    op_states tx_fsm, next_tx_fsm;

    logic sreg_en;
    logic load_en;
    logic reg_out;
    logic cb_incr;
    logic last_tick;
    logic last_bit;
    logic stop_bits;
    logic parity;
    logic parity_bit;
    logic half_parity;
    logic [TICK_BW:0] count_ticks;
    logic [$clog2(DATA_WIDTH)-1:0] count_bits;
    logic [$clog2(DATA_WIDTH)-1:0] cb_next;


    shift_reg #(.N(DATA_WIDTH)) tsr (
        .clk(first_tick),
        .res_n(res_n),
        .en(sreg_en),
        .din(),
        .dout(),
        .load_en(load_en),
        .load(tx_din),
        .dout_n(reg_out)
    );

    // Cycle logic
    //TODO: this one alywasy counting
    assign first_tick = ~|count_ticks;
    assign last_tick = &count_ticks;   // | (tx_fsm == STOP_HALF & count_ticks == HALF_CYCLE)
    always_ff @(posedge baudout or negedge res_n) begin
        if (~res_n)
            count_ticks <= 0;
        else if (tx_fsm == STOP_HALF)
            count_ticks <= (count_ticks | (1 << TICK_BW)) + 1;
        else
            count_ticks <= count_ticks + 1;
    end

    // Bits counter
    assign cb_next = count_bits + cb_incr;
    always_ff @(posedge first_tick) begin
        if (~cb_incr | last_bit)
            count_bits <= 0;
        else
            count_bits <= cb_next;
    end


    assign last_bit     = count_bits[2] & count_bits[1:0] == lcreg[`UART_LCR_WLS +: 2];    // 4 to 7
    assign stop_bits    = lcreg[`UART_LCR_STB];
    assign half_parity  = ~|lcreg[`UART_LCR_WLS +: 2] & stop_bits;

    always_comb begin
        case (lcreg[`UART_LCR_WLS +: 2])
            2'b00: parity = ^tx_din[4:0];
            2'b01: parity = ^tx_din[5:0];
            2'b10: parity = ^tx_din[6:0];
            2'b11: parity = ^tx_din;
        endcase
    end

    // Odd  Parity: parity bit is set to 1 if xor is 0
    // Even Parity: parity bit is set to 1 if xor is 1
    always_comb begin
        if (lcreg[`UART_LCR_SP])
            parity_bit = ~lcreg[`UART_LCR_EPS];
        else if (lcreg[`UART_LCR_EPS])
            parity_bit = parity;
        else
            parity_bit = ~parity;
    end

    // Demux
    always_comb begin
        case (tx_fsm)
            START: begin
                tsr_empty = 1'b0;
                tx_dout = 1'b0;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                load_en = 1'b1;
                tx_ready = 1'b0;
            end
            DATA: begin
                tsr_empty = 1'b0;
                tx_dout = reg_out;
                cb_incr = 1'b1;
                sreg_en = 1'b1;
                load_en = 1'b0;
                tx_ready = 1'b0;
            end
            PARITY: begin
                tsr_empty = 1'b0;
                tx_dout = parity_bit;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                load_en = 1'b0;
                tx_ready = 1'b0;
            end
            STOP: begin
                tsr_empty = 1'b1;
                tx_dout = 1'b1;
                cb_incr = 1'b1;
                sreg_en = 1'b0;
                load_en = 1'b0;
                tx_ready = count_bits == 0 & count_ticks == 1;
            end
            default: begin
                tsr_empty = 1'b1;
                tx_dout = 1'b1;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                load_en = 1'b0;
                tx_ready = 1'b0;
            end
        endcase
    end

    // FSM logic
    always_latch begin
        case (tx_fsm)
            START: begin
                next_tx_fsm = DATA;
            end
            DATA: begin
                if (last_bit) begin
                    if (lcreg[`UART_LCR_PEN])
                        next_tx_fsm = PARITY;
                    else
                        next_tx_fsm = STOP;
                end
            end
            PARITY: begin
                next_tx_fsm = STOP;
            end
            STOP: begin
                if (half_parity)
                    next_tx_fsm = STOP_HALF;
                else if (count_bits == stop_bits) begin
                    if (tx_start)
                        next_tx_fsm = START;
                    else
                        next_tx_fsm = IDLE;
                end
            end
            STOP_HALF: begin
                //if (last_tick) begin
                    if (tx_start)
                        next_tx_fsm = START;
                    else
                        next_tx_fsm = IDLE;
                //end
            end
            default: begin
                // will move to START only on last tick. TBD: move it sooner?
                if (tx_start)
                    next_tx_fsm = START;
                else
                    next_tx_fsm = IDLE;
            end
        endcase
    end
    always_ff @(posedge first_tick or negedge res_n) begin
        if (~res_n)
            tx_fsm <= IDLE;
        else
            tx_fsm <= next_tx_fsm;
        `ifdef DEBUG_RUN
            $strobe("DEBUG: [Tx_uart] tx_din=%0b tx_dout=%0b count_bits=%0d", tx_din, tx_dout, count_bits);
        `endif
    end
endmodule
