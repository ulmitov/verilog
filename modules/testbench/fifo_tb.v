`timescale 1ns / 100ps

`define VCD "vcd/fifo_tb.vcd"
`define DATA_WIDTH 8
`define ADDR_WIDTH 3

`define T_WR 5
`define T_RD 5


module fifo_tb;
    localparam DEPTH = 2**`ADDR_WIDTH;
    localparam TCLK = `T_WR * 2;
    reg clk = 1'b0;
    reg wen, ren, res;
    reg [`DATA_WIDTH-1:0] data;
    wire [`DATA_WIDTH-1:0] out;
    wire [`ADDR_WIDTH:0] count;
    wire full, empty;
    integer i;
    reg err;
    reg [`DATA_WIDTH-1:0] exp_fifo [DEPTH-1:0];

    fifo #( .DATA_WIDTH(`DATA_WIDTH), .ADDR_WIDTH(`ADDR_WIDTH) ) UUT(
        .res(res),
        .clk(clk),
        .push(wen),
        .pull(ren),
        .din(data),
        .dout(out),
        .empty(empty),
        .full(full)
        ,.count(count)
    );

    always #`T_RD clk = ~clk;
    always @(posedge clk) if (err) #`T_RD $finish;

    task ASSERT;
        input integer ex_empty;
        input integer ex_full;
        input integer ex_items;
    begin
        err = 0;
        if (full  !== ex_full) begin
            err = 1;
            $display("[fifo_tb] ERROR: full=%0b  not as expected %0b", full, ex_full);
        end
        if (empty !== ex_empty) begin
            err = 1;
            $display("[fifo_tb] ERROR: empty=%0b not as expected %0b", empty, ex_empty);
        end
        if (count !== 'hX && count != ex_items) begin
            err = 1;
            $display("[fifo_tb] ERROR: count=%0b not as expected %0b", count, ex_items);
        end
    end
    endtask

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%0t: wen=%0b  ren=%0b  data=%0h  out=%0h  full=%0b  empty=%0b  count=%0d", $time, wen, ren, data, out, full, empty, count);

        $display("Test reset and stuck 1's");
        wen = 1'b0;
        ren = 1'b0;
        res = 1'b1;
        #TCLK res = 1'b0;
        ASSERT(1, 0, 0);

        $display("Test empty 0");
        data = 'hAA;
        wen = 1'b1;
        #TCLK wen = 1'b0;
        ASSERT(0, 0, 1);

        $display("---Test empty 1");
        ren = 1'b1;
        #TCLK ren = 1'b0;
        ASSERT(1, 0, 0);

        $display("---Test empty 0 and max count");
        wen = 1'b1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            data = i;
            exp_fifo[i] = i;
            #TCLK ASSERT(0, i == DEPTH-1, i + 1);
        end

        $display("---Test try to write when full");
        data = 'hEE;
        #TCLK ASSERT(0, 1, DEPTH);

        $display("---Test reads");
        wen = 1'b0;
        ren = 1'b1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (out != exp_fifo[i]) $display("%t ERROR: out %0h is not %0h", $time, out, exp_fifo[i]);
            #TCLK;
        end

        $display("---Test stuck 0's");
        wen = 1'b1;
        ren = 1'b0;
        for (i = 0; i < DEPTH; i = i + 1) begin
            data = 'hFF;
            #TCLK ASSERT(0, i == DEPTH-1, i + 1);
        end
        wen = 1'b0;
        ren = 1'b1;
        $display("---Test count and full 0 and dout is correct");
        for (i = 0; i < DEPTH; i = i + 1) begin
            #TCLK if (out != 'hFF) $display("%0t ERROR: out %0h is not 0xFF", $time, out);
        end


        $display("---Test parallel read-write");
        wen = 1'b1;
        ren = 1'b0;
        // make one write before reading, then each read expects previous write val
        data = DEPTH - 1;
        #TCLK ren = 1'b1;
        for (i = DEPTH - 1; i > 0; i = i - 1) begin
            if (out != i) $display("%t ERROR: out %0h is not %0h", $time, out, i);
            data = i - 1;
            #TCLK ASSERT(0, 0, 1);
        end

        #TCLK if (~err) $display("*** FIFO TB PASSED ! ***");
        $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
