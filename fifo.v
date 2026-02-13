/*
Synchronous FIFO with parallel read-write

Core Output Flags (Essential)

    Empty (empty): Asserted when the FIFO contains no data. Read operations should be halted when this flag is high.
    Full (full): Asserted when the FIFO is completely full. Write operations should be halted when this flag is high to prevent data loss. 

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

Clock Domain Behaviors

    Synchronous/Common Clock: All flags are synchronized to the single system clock.
    Asynchronous/Independent Clocks: empty, almost_empty, and data_valid are typically synchronized to the read clock (rd_clk), while full, almost_full, and wr_ack are synchronized to the write clock (wr_clk). 

FIFO Read Modes

    Standard Mode: Read latency is higher; data appears on the output bus after a read enable is issued.
    First-Word Fall-Through (FWFT): The first word is available immediately on the output bus when the FIFO is not empty, reducing latenc


f="fifo"; m="fifo";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.v"


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
);
    reg [DATA_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;

    // write op
    always @(posedge clk) begin
        if (res)
            w_ptr <= 0;
        else if (push & ~full) begin
            w_ptr <= #`T_DELAY_FF w_ptr + 1;
            mem[w_ptr] <= #`T_DELAY_FF din;
        end
        `ifdef DEBUG $display("FIFO: w_ptr=%0d push=%0b din=%0h", w_ptr, push, din);
    end

    // read op
    assign #`T_DELAY_PD dout = mem[r_ptr];      // for now always setting current mem value even if x

    always @(posedge clk) begin
        if (res) begin
            r_ptr <= 0;
        end else if (pull & ~empty) begin
            //dout <= mem[r_ptr];   // instead of FFs, using the assign below
            r_ptr <= #`T_DELAY_FF r_ptr + 1;
        end
        `ifdef DEBUG $display("FIFO: r_ptr=%0d pull=%0b dout=%0h", r_ptr, pull, dout);
    end

    

    reg pushed;
    wire ptmet;
    integer i;

    assign ptmet = &(r_ptr ~^ w_ptr);   // pointers met - not using, replaced by checking the counter
    assign full  = ptmet & pushed;      // if MSB is set then we got to the max count of items
    assign empty = ptmet & ~pushed;     // at least one item was pushed

    always @(posedge clk) begin
        if (res) begin
            pushed <= 1'b0;
        end else if (push & ~full & ~pull) begin
            // push
            pushed <= 1'b1;
        end else if (pull & ~empty) begin // even if push and pull in parallel
            // pull
            pushed <= 1'b0;
        end
        `ifdef DEBUG
            $display("Current FIFO state:");
            for (i = 0; i < 2**ADDR_WIDTH; i = i + 1)
                $display("mem[%0d] = 0x%h", i, mem[i]); 
        `endif
    end
    /*
        reg [ADDR_WIDTH:0] count_add;

        assign full  = count[ADDR_WIDTH];   // if MSB is set then we got to the max count of items
        assign empty = ~|count;             // at least one item was pushed

        // looks like if the casez is in separate combinational logic the synth has less elements, though not a big differrence
        always @(*) begin
            // 4to1 mux
            casez ({pull, push, empty, full})
                4'b100?: count_add = -1;
                4'b01?0: count_add = 1;
                default: count_add = 0;
            endcase
        end

        always @(posedge clk) begin
            if (res)
                count <= 0;
            else begin
                count <= count + count_add;
            end
        end
    */
endmodule
