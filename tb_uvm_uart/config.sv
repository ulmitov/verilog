`include "regmap.vh"


package config_pkg;
parameter int SETUP_TIME = `T_DELAY_FF + 1;
parameter int HOLDTIME = `T_DELAY_PD;
parameter int DWIDTH = `UART_DATA_WIDTH;
parameter int AWIDTH = `UART_ADDR_WIDTH;
parameter int APB_DATA_WIDTH = 32;
parameter int APB_ADDR_WIDTH = 32;// not used!!!
parameter int NUM_TICKS = `UART_TICKS_NUM;
parameter int TCLK = 5;
parameter int UART_BASE_ADDRESS = 'h0;
parameter int SEQ_REPEAT = 7;   // how much sequences to run in eah test (min is 5)
parameter int FIFO_DEPTH = 1 << `UART_FIFO_ADDR_W;
typedef enum logic [2:0] { IDLE, START, DATA, PARITY, STOP, STOP2, STOP_HALF } op_states;
typedef int patterns_arr[SEQ_REPEAT];
endpackage


class top_config extends uvm_object;
    `uvm_object_utils(top_config)

    int LOOPBACK;
    int WORD_LEN;
    int STOP_BITS;
    int PARITY_EN;
    int EVEN_PARITY;
    int STICK_PARITY;
    logic [`UART_DIV_WIDTH-1:0] DIVISOR = 'bX;

    function new(string name="CFG");
        super.new(name);
        init();
    endfunction

    function void init();
        WORD_LEN = 5;
        STOP_BITS = 1;
        PARITY_EN = 0;
        EVEN_PARITY = 0;
        STICK_PARITY = 0;
        LOOPBACK = 0;
        //DIVISOR = 1;
    endfunction

    function int get_ticks_per_bit;
        return config_pkg::NUM_TICKS * DIVISOR;
    endfunction

    function int get_ticks_per_word;
        real sb = STOP_BITS == 2 && WORD_LEN == 5 ? 1.5 : STOP_BITS;
        get_ticks_per_word = get_ticks_per_bit() * (WORD_LEN + sb + PARITY_EN + 1);
    endfunction

    function bit get_parity_bit(int value);
        bit parity_val;
        if (this.STICK_PARITY) begin
            parity_val = ~this.EVEN_PARITY;
        end else begin
            parity_val = ^value;
            if (!this.EVEN_PARITY) parity_val = ~parity_val;
        end
        return parity_val;
    endfunction

    function int get_divisor(real rate);
        real sb = STOP_BITS == 2 && WORD_LEN == 5 ? 1.5 : STOP_BITS;
        rate = rate * config_pkg::NUM_TICKS * (WORD_LEN + sb + PARITY_EN + 1) / 8;
        rate = rate * config_pkg::TCLK * 2;
        get_divisor = 10**7 / rate;
    endfunction
endclass
