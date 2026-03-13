/*
    UART Transceiver
*/
module uart_tx #(parameter DATA_WIDTH = 8, parameter STOP_BITS = 2, parameter TICKS_NUM = 16) (
    input clk,
    input res_n,
    input tx_baud,
    input tx_start,
    input [DATA_WIDTH-1:0] tx_din,
    output logic tx_dout,
    output logic tx_ready
);
    localparam TICK_BW = $clog2(TICKS_NUM)-1;

    typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP } op_states;
    op_states state, next_state;

    logic sreg_en;
    logic load_en;
    logic reg_out;
    logic parity;
    logic parity_bit;
    logic last_tick;
    logic tx_pulled;
    logic cb_incr;
    logic [TICK_BW:0] count_ticks;
    logic [$clog2(DATA_WIDTH)-1:0] count_bits, cb_next;

    shift_reg #(.N(DATA_WIDTH)) tx_reg (
        .clk(last_tick),
        .res_n(res_n),
        .en(sreg_en),
        .din(reg_out),
        .dout(),
        .load_en(load_en),
        .load(tx_din),
        .dout_n(reg_out)
    );

    // Cycle logic
    assign last_tick = &count_ticks;
    always_ff @(posedge tx_baud or negedge res_n) begin
        if (~res_n)
            count_ticks <= 0;
        else
            count_ticks <= count_ticks + 1;
    end

    // Bits counter
    assign cb_next = count_bits + cb_incr;
    always_ff @(posedge last_tick) begin
        if (~cb_incr)
            count_bits <= 0;
        else
            count_bits <= cb_next;
    end

    // Same as rx_ready in Rx. pull from TxFifo should be done according to system clock
    // on first clock not pulled yet
    always_ff @(posedge clk) tx_pulled <= load_en;
    always_ff @(posedge clk) tx_ready <= load_en & ~tx_pulled;

    assign parity = ^tx_din;
    logic [2:0] PARITY_REG;
    assign PARITY_REG = 3;
    always_comb begin
        case ({PARITY_REG[2:1]})
            2'b00: parity_bit = ~parity; //0 is odd, 1 is even parity=1? 0:1
            2'b01: parity_bit = parity; 
            2'b10: parity_bit = 1'b1;
            2'b11: parity_bit = 1'b0;
        endcase
    end

    // Demux
    always_comb begin
        case (state)
            START: begin
                tx_dout = 1'b0;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                load_en = 1'b1;
            end
            DATA: begin
                tx_dout = reg_out;
                cb_incr = 1'b1;
                sreg_en = 1'b1;
                load_en = 1'b0;
            end
            PARITY: begin
                tx_dout = parity_bit;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
            end
            STOP: begin
                tx_dout = 1'b1;
                cb_incr = 1'b1;
                sreg_en = 1'b0;
            end
            default: begin
                tx_dout = 1'b1;
                cb_incr = 1'b0;
                sreg_en = 1'b0;
                load_en = 1'b0;
            end
        endcase
    end

    // FSM logic
    always_comb begin
        case (state)
            START: begin
                next_state = DATA;
            end
            DATA: begin
                if (&count_bits) begin
                    if (PARITY_REG[0])
                        next_state = PARITY;
                    else
                        next_state = STOP;
                end
            end
            PARITY: begin
                next_state = STOP;
            end
            STOP: begin
                if (count_bits == STOP_BITS - 1) begin
                    if (tx_start)
                        next_state = START;
                    else
                        next_state = IDLE;
                end
            end
            default: begin
                if (tx_start) next_state = START;
            end
        endcase
    end
    always_ff @(posedge last_tick or negedge res_n) begin
        if (~res_n)
            state <= IDLE;
        else
            state <= next_state;
        `ifdef DEBUG
            $strobe("DEBUG: [Tx_uart] tx_din=%0b tx_dout=%0b count_bits=%0d", tx_din, tx_dout, count_bits);
        `endif
    end
endmodule
