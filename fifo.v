/*
Synchronous FIFO with parallel read-write

f="fifo"; m="fifo";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
//`define COUNTER_LOGIC


module fifo #(
    parameter ADDR_WIDTH = 3,   // how much addresses, so depth is 2**ADDR_WIDTH
    parameter WORD_WIDTH = 8
) (
    input res,
    input clk,
    input push,
    input pull,
    input wire [WORD_WIDTH-1:0] din,    // pushes a value into fifo
    output wire [WORD_WIDTH-1:0] dout,  // pulls a value from fifo
    output reg [ADDR_WIDTH:0] count,    // counter shows how much the fifo is filled
    output wire empty,
    output wire full
);
    reg [WORD_WIDTH-1:0] mem [2**ADDR_WIDTH-1:0];
    reg [ADDR_WIDTH-1:0] w_ptr, r_ptr;

    // write op
    always @(posedge clk) begin
        if (res)
            w_ptr <= 0;
        else if (push & ~full) begin
            w_ptr <= w_ptr + 1;
            mem[w_ptr] <= din;
        end
    end

    // read op
    always @(posedge clk) begin
        if (res) begin
            r_ptr <= 0;
        end else if (pull & ~empty) begin
            //dout <= mem[r_ptr];   // instead of FFs, using the assign
            r_ptr <= r_ptr + 1;
        end
    end

    assign dout  = mem[r_ptr];      // for now always setting current mem value even if x

    `ifndef COUNTER_LOGIC
        reg pushed;
        wire ptmet;

        assign ptmet = &(r_ptr ~^ w_ptr);   // pointers met - not using, replaced by checking the counter
        assign full  = ptmet & pushed;      // if MSB is set then we got to the max count of items
        assign empty = ptmet & ~pushed;     // at least one item was pushed
        always @(posedge clk) begin
            if (res) begin
                pushed <= 1'b0;
            end else if (push & ~full & ~pull) begin
                // push
                pushed <= 1'b1;
            end else if (pull & ~empty) begin // even if if push and pull in parallel
                // pull
                pushed <= 1'b0;
            end
        end
    `else
        reg [ADDR_WIDTH:0] count_add;

        assign full  = count[ADDR_WIDTH];   // if MSB is set then we got to the max count of items
        assign empty = ~|count;             // at least one item was pushed

        // looks like if the casez is in separate combinational logic the synth has less elements, though not a big differrence
        // but anyway this counter is additional adder logic, TODO: remove it and stay with the above logic?
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
    `endif
endmodule
