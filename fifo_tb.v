
`timescale 1ns / 100ps

`define DATA_WIDTH 8
`define ADDR_WIDTH 3

`define T_WR 5
`define T_RD 5
`define T_CLK (`T_WR * 2)


module fifo_tb;
    reg clk = 1'b0;
    reg wen, ren, res;
    reg [`DATA_WIDTH-1:0] data;
    wire [`DATA_WIDTH-1:0] out;
    wire [`ADDR_WIDTH:0] count;
    wire full, empty;
    integer i;
    reg [`DATA_WIDTH-1:0] exp_fifo [2**`ADDR_WIDTH-1:0];

    fifo #( .DATA_WIDTH(`DATA_WIDTH), .ADDR_WIDTH(`ADDR_WIDTH) ) UUT(
        .res(res),
        .clk(clk),
        .push(wen),
        .pull(ren),
        .din(data),
        .dout(out),
        .empty(empty),
        .full(full),
        .count(count)
    );

    always #`T_RD clk = ~clk;

    `define _ASSERT(ex_empty, ex_full, ex_items) \
    begin \
        if (full  !== ex_full)  $display("* ERROR: full=%0b  not as expected %0b", full, ex_full);   \
        if (empty !== ex_empty) $display("* ERROR: empty=%0b not as expected %0b", empty, ex_empty); \
        if (count != ex_items) $display("* ERROR: count=%0b not as expected %0b", count, ex_items); \
    end

    initial begin
        $dumpfile("vcd/fifo_tb.vcd");
        $dumpvars();
        $monitor("%0d: wen=%0b, ren=%0b, data=%0h, out=%0h, full=%0b, empty=%0b, count=%0d", $time, wen, ren, data, out, full, empty, count);

        $display("Test reset and struck at 1's");
        wen = 1'b0;
        ren = 1'b0;
        res = 1'b1;
        #`T_CLK res = 1'b0;
        `_ASSERT(1, 0, 0);

        $display("Test empty 0");
        data = 'hAA;
        wen = 1'b1;
        #`T_CLK wen = 1'b0;
        `_ASSERT(0, 0, 1);

        $display("---Test empty 1");
        ren = 1'b1;
        #`T_CLK ren = 1'b0;
        `_ASSERT(1, 0, 0);

        $display("---Test empty 0 and max count");
        wen = 1'b1;
        for (i = 0; i < 2**`ADDR_WIDTH; i = i + 1) begin
            data = i;
            exp_fifo[i] = i;
            #`T_CLK `_ASSERT(0, i == 2**`ADDR_WIDTH - 1, i + 1);
        end

        $display("---Test try to write when full");
        data = 'hEE;
        #`T_CLK `_ASSERT(0, 1, 2**`ADDR_WIDTH);

        $display("---Test reads");
        wen = 1'b0;
        ren = 1'b1;
        for (i = 0; i < 2**`ADDR_WIDTH; i = i + 1) begin
            if (out != exp_fifo[i]) $display("ERROR: out %0h is not %0h", out, exp_fifo[i]);
            #`T_CLK;
        end

        $display("---Test stuck at 0's");
        wen = 1'b1;
        ren = 1'b0;
        for (i = 0; i < 2**`ADDR_WIDTH; i = i + 1) begin
            data = 'hFF;
            #`T_CLK `_ASSERT(0, i == 2**`ADDR_WIDTH - 1, i + 1);
        end
        wen = 1'b0;
        ren = 1'b1;
        $display("---Test count and full 0 and dout is correct");
        for (i = 0; i < 2**`ADDR_WIDTH; i = i + 1) begin
            #`T_CLK if (out != 'hFF) $display("ERROR: out %0h is not 0xFF", out);
        end


        $display("---Test parallel read-write");
        wen = 1'b1;
        ren = 1'b0;
        // make one write before reading, then each read expects previous write val
        data = 2**`ADDR_WIDTH - 1;
        #`T_CLK ren = 1'b1;
        for (i = 2**`ADDR_WIDTH - 1; i >0; i = i - 1) begin
            if (out != i) $display("ERROR: out %0h is not %0h", out, i);
            data = i - 1;
            #`T_CLK `_ASSERT(0, 0, 1);
        end

        #`T_CLK $finish;
    end
endmodule
