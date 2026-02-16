/*
Synchronous FIFO with parallel read-write

Design:

All flags are synchronized to the single system clock
First-Word Fall-Through (FWFT): The first word is available immediately on the output bus when the FIFO is not empty, reducing latenc

Because of metastablity it would be safer to indicate ptmet when there is one cell left.
So full is the meeting of next wr and current rd pointers.
And empty is the meeting of next wr and next rd (or current wr and rd).
If there are two clocks, then wr pointer moves at one speed and rd pointer moves another speed.
Then to get a stable ptmet it would be much safer to use gray code.
So using gray code and checking equivalence of next pointers, highly guarantees a stable operation in two clock domains.
But if there is a need for items counter ouput, then design should be more sophisticated.

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
`include "consts.v"

//`define COUNTER_LOGIC


module fifo #(
    parameter ADDR_WIDTH = 3,           // how much addresses, so depth is 2**ADDR_WIDTH
    parameter DATA_WIDTH = 8
) (
    input res,
    input clk,
    input push,
    input pull,
    input wire [DATA_WIDTH-1:0] din,    // pushes a value into fifo
    output wire [DATA_WIDTH-1:0] dout,  // pulls a value from fifo
    output wire empty,
    output wire full
`ifdef COUNTER_LOGIC
    ,output reg [ADDR_WIDTH-1:0] count,    // items counter. if this logic is required then uncomment the define line
`endif
);
    reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;
    reg [ADDR_WIDTH-1:0] next_w, next_r;
    wire ren, wen;

    // write op
    assign wen = push & ~full;
    always @(posedge clk) begin
        if (res)
            next_w <= 1'b1;
        else if (wen)
            next_w <= #`T_DELAY_FF next_w + 1;
    end
    always @(posedge clk) begin
        if (res)
            w_ptr <= 0;
        else if (wen) begin
            w_ptr <= #`T_DELAY_FF next_w;
            mem[w_ptr] <= #`T_DELAY_FF din;
        end
        `ifdef DEBUG $display("FIFO: w_ptr=%0d next_w=%0d, push=%0b din=%0h", w_ptr, next_w, push, din);
    end

    // read op
    assign #`T_DELAY_PD dout = mem[r_ptr];      // for now always setting current mem value even if x
    assign ren = pull & ~empty;

    always @(posedge clk) begin
        if (res)
            next_r <= 1'b1;
        else if (ren)
            next_r <= #`T_DELAY_FF next_r + 1;
    end
    always @(posedge clk) begin
        if (res)
            r_ptr <= 0;
        else if (ren)
            r_ptr <= #`T_DELAY_FF next_r;
        `ifdef DEBUG $display("FIFO: r_ptr=%0d next_r=%0d, pull=%0b dout=%0h", r_ptr, next_r, pull, dout);
    end

    `ifndef COUNTER_LOGIC
        reg pushed;
        wire ptmet;
        integer i;

        assign ptmet = &(r_ptr ~^ next_w); // pointers met
        assign full  = &(r_ptr ~^ next_w) & pushed;      // if pointers met and there was a push means we are full
        assign empty = &(r_ptr ~^ w_ptr) & ~pushed;     // if pointers met but there was no push then we are empty

        always @(posedge clk) begin
            if (res)
                pushed <= 1'b0;
            else if (wen & ~pull)
                pushed <= 1'b1;
            else if (ren)           // also when push and pull both set
                pushed <= 1'b0;
            `ifdef DEBUG
                $display("Current FIFO state:");
                for (i = 0; i < 2**ADDR_WIDTH; i = i + 1)
                    $display("mem[%0d] = 0x%h", i, mem[i]); 
            `endif
        end
    `else
        reg [ADDR_WIDTH-1:0] count_add;

        // if only one cell empty left then sig raised
        assign full  = &count[ADDR_WIDTH-1:1] & ~count[0];
        assign empty = ~|count;

        always @(*) begin
            // 4to1 mux
            casez ({pull, push, empty, full})
                4'b100?: count_add = -1;
                4'b01?0: count_add = 1;
                default: count_add = 0; // if pull and push are set then also no change
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
