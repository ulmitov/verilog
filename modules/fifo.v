/*
Synchronous FIFO with parallel read-write

Design:

All flags are synchronized to the single system clock
First-Word Fall-Through (FWFT): The first word is available immediately on the output bus when the FIFO is not empty, reducing latency

TODO:
    Asynchronous/Independent Clocks: empty, almost_empty, and data_valid are typically synchronized to the read clock (rd_clk), while full, almost_full, and wr_ack are synchronized to the write clock (wr_clk). 
Status & Management Flags (Common)
    Almost Empty (almost_empty): Indicates the FIFO is nearly empty (e.g., only one word remains). Used to signal that a read operation should cease soon.
    Almost Full (almost_full): Indicates the FIFO is nearly full (e.g., one more write can be accepted). Used to warn the producer to stop writing.
    Data Valid (data_valid / valid): In standard mode, indicates that the data on the output bus (dout) is valid for sampling.
    Write Acknowledge (wr_ack): Asserted to indicate that a write request was successful. 

Error & Programmable Flags
    Underflow (underflow): Asserted if a read request is made while the FIFO is empty. Usually indicates an error in control logic.
    Overflow (overflow): Asserted if a write request is made while the FIFO is full.
    Programmable Full (prog_full): A user-defined threshold flag that asserts when the fill level exceeds a set limit.
    Programmable Empty (prog_empty): A user-defined threshold flag that asserts when the fill level falls below a set limit. 

f="fifo"; m="fifo";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.vh"

`define COUNTER_LOGIC     // if this logic is required then uncomment the define line


module fifo #(
    parameter ADDR_WIDTH = 3,           // address bit width, so depth is 2**ADDR_WIDTH
    parameter DATA_WIDTH = 8,
    parameter name="FIFO"
) (
    input res,
    input clk,
    input en,                           // if not en then fifo is just a static register
    input push,
    input pull,
    input wire [DATA_WIDTH-1:0] din,    // pushes a value into fifo
    output wire [DATA_WIDTH-1:0] dout,  // pulls a value from fifo
    output wire empty,
    output wire full,
    output wire half_full
//`ifdef COUNTER_LOGIC
    ,output reg [ADDR_WIDTH:0] count  // items counter
//`endif
);
    reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;
    reg [ADDR_WIDTH-1:0] next_w, next_r;
    wire ren, wen;
    wire ptmet;              // pointers met

    assign wen = push & ~full;
    assign ren = pull & ~empty;
    assign ptmet = &(r_ptr ~^ w_ptr);

    /* WRITE */
    always @(posedge clk) begin
        if (res)
            next_w <= {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        else if (wen & en)
            next_w <= #`T_DELAY_FF next_w + 1;
    end
    always @(posedge clk) begin
        if (res)
            w_ptr <= 0;
        else if (wen & en)
            w_ptr <= #`T_DELAY_FF next_w;
    end
    always @(posedge clk) begin
        if (~res & wen) mem[w_ptr] <= #`T_DELAY_FF din;
        `ifdef DEBUG_RUN
            if (push)
                $display("DEBUG: %s PUSH:  w_ptr=%0d  next_w=%0d  din=%0h  full=%0b", name, w_ptr, next_w, din, full);
        `endif
    end

    /* READ */
    assign #`T_DELAY_PD dout = mem[r_ptr];      // for now always setting current mem value even if x
    
    always @(posedge clk) begin
        if (res)
            next_r <= {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
        else if (ren & en)
            next_r <= #`T_DELAY_FF next_r + 1;
    end
    always @(posedge clk) begin
        if (res)
            r_ptr <= 0;
        else if (ren & en)
            r_ptr <= #`T_DELAY_FF next_r;
        `ifdef DEBUG_RUN
            if (ren)
                $display("DEBUG: %s PULL:  r_ptr=%0d  next_r=%0d  dout=%0h  empty=%0b", name, r_ptr, next_r, dout, empty);
        `endif
    end

    `ifndef COUNTER_LOGIC
        reg pushed;

        assign empty = ptmet & ~pushed;     // if pointers met but there was no push then we are empty
        assign full  = (ptmet | ~en) & pushed;     // if pointers met and there was a push means we are full
        //assign half_full = w_ptr == r_ptr << 1;

        always @(posedge clk) begin
            if (res)
                pushed <= 1'b0;
            else if (wen | (push & pull))
                pushed <= 1'b1;
            else if (ren)           // also when push and pull both set
                pushed <= 1'b0;
        end
    `else
        reg [ADDR_WIDTH:0] count_add;

        assign empty = ~|count;
        assign full  = (count[ADDR_WIDTH] & en) | (~en & ~empty);
        assign half_full = count >= (2**ADDR_WIDTH >> 1);

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
    `endif
endmodule
