/*
Synchronous FIFO with parallel read-write

SPEC: https://docs.amd.com/api/khub/documents/nnCmr3UMFG34c9PLASZvHw/content

Design:

All flags are synchronized to the single system clock
First-Word Fall-Through (FWFT): The first word is available immediately 
on the output bus when the FIFO is not empty, reducing latency

TODO:
    Asynchronous/Independent Clocks: empty, almost_empty, and data_valid are
    typically synchronized to the read clock (rd_clk), while full, almost_full
    and wr_ack are synchronized to the write clock (wr_clk). 

m="fifo"; yosys -p "read_verilog ${m}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.vh"


module fifo #(
    parameter name="FIFO",
    parameter ADDR_WIDTH = 3,           // address bit width, so depth is 2**ADDR_WIDTH
    parameter DATA_WIDTH = 8
) (
    input res,
    input clk,
    input push,
    input pull,
    input wire [DATA_WIDTH-1:0] din,    // pushes a value into fifo
    output wire [DATA_WIDTH-1:0] dout,  // pulls a value from fifo
    output wire empty,
    output wire full,
    output reg [ADDR_WIDTH:0] count     // items counter
);
    reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;
    reg [ADDR_WIDTH-1:0] next_w, next_r;
    wire ren, wen;

    assign wen = push & ~full;
    assign ren = pull & ~empty;

    /* WRITE */
    always @(posedge clk) begin
        if (res)
            next_w <= {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        else if (wen)
            next_w <= #`T_DELAY_FF next_w + 1;
    end
    always @(posedge clk) begin
        if (res)
            w_ptr <= 0;
        else if (wen)
            w_ptr <= #`T_DELAY_FF next_w;
    end
    always @(posedge clk) begin
        if (~res & wen) mem[w_ptr] <= #`T_DELAY_FF din;
        `ifdef DEBUG_RUN
            if (push)
                $display("DEBUG: %s PUSH:  w_ptr=%0d  next_w=%0d  din=%0h  full=%0b  empty=%0b", name, w_ptr, next_w, din, full, empty);
        `endif
    end

    /* READ (FWFT mode) */
    assign #`T_DELAY_PD dout = mem[r_ptr];

    always @(posedge clk) begin
        if (res)
            next_r <= {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        else if (ren)
            next_r <= #`T_DELAY_FF next_r + 1;
    end
    always @(posedge clk) begin
        if (res)
            r_ptr <= 0;
        else if (ren)
            r_ptr <= #`T_DELAY_FF next_r;
        `ifdef DEBUG_RUN
            if (ren)
                $display("DEBUG: %s PULL:  r_ptr=%0d  next_r=%0d  dout=%0h  empty=%0b", name, r_ptr, next_r, dout, empty);
        `endif
    end
    /*
        reg pushed;
        wire ptmet;              // pointers met
        assign ptmet = &(r_ptr ~^ w_ptr);
        assign empty = ptmet & ~pushed;     // if pointers met but there was no push then we are empty
        assign full  = ptmet & pushed;     // if pointers met and there was a push means we are full
        //assign half_full = w_ptr == r_ptr << 1;
        always @(posedge clk) begin
            if (res)
                pushed <= 1'b0;
            else if (wen | (push & pull))
                pushed <= 1'b1;
            else if (ren)           // also when push and pull both set
                pushed <= 1'b0;
        end
    */
    reg [ADDR_WIDTH:0] count_add;

    assign empty = ~|count;
    assign full  = count[ADDR_WIDTH];

    always @(*) begin
        casez ({pull, push, empty, full})
            4'b100?: count_add = -1;
            4'b01?0: count_add = 1;
            4'b1110: count_add = 1; // pull fail on parrallel
            default: count_add = 0; // no change on parrallel
        endcase
    end

    always @(posedge clk) begin
        if (res)
            count <= 0;
        else
            count <= count + count_add;
    end
endmodule
