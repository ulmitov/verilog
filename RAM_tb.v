`include "consts.v"

`timescale 1ns / 1ns

`define T_WR 10
`define T_RD 10
`define T_CLK (`T_WR * 2)

`define D_WIDTH 4   // Memory data word width
`define D_DEPTH 8  // Memory depth
// TODO: simultaneous read\write test? two clocks test? minimum f test? `define RO_DELAY (`T_DELAY_FF + `T_WR)


module RAM_tb;
    reg clk, rclk, we, re, res;
    reg [$clog2(`D_DEPTH)-1:0] add;
    reg [`D_WIDTH-1:0] data, exp;
    reg [`D_WIDTH-1:0] exp_ram [`D_DEPTH-1:0];
    wire [`D_WIDTH-1:0] out;
    wire done_flag;
    integer i, j;

    RAM #( .WIDTH(`D_WIDTH), .DEPTH(`D_DEPTH), .RCLK_EDGE("RISE")) uut (
        .wclk(clk),
        .rclk(rclk),
        .res(res),
        .wen(we),
        .ren(re),
        .data(data),
        .address(add),
        .Q(out)
    );

    // clock generation
    always #`T_WR clk = ~clk;
    always #`T_RD rclk = ~rclk;

    // write operation
    task w_op;
        input [$clog2(`D_DEPTH)-1:0] address;
        input [`D_WIDTH-1:0] din;
        begin
            add = address;
            we = 1;
            data = din;
            //wait (done_flag == 1);
            //@(done_flag);
            //we = 0;
            #`T_CLK we = 0;
            exp_ram[address] = din;
        end
    endtask

    // read operation
    task r_op;
        input [$clog2(`D_DEPTH)-1:0] address;
        input [`D_WIDTH-1:0] din;
        begin
            add = address;
            we = 0;
            re = 1;
            if (uut.RCLK_EDGE == "NONE")
                #`T_CLK re = 0; // if async then wait only flip flop delay ?
            else
                #`T_CLK re = 0;
            if (out !== din) $display("%0d: ERROR: add=%0h: out=%0h not as expected %0h", $time, add, out, din);
        end
    endtask

    // read whole ram and compare to expected
    task check_ram;
        integer a;
        for (a = 0; a < `D_DEPTH; a = a + 1)
            r_op(a, exp_ram[a]);
    endtask

    // stimulus
    initial begin
        $dumpfile("vcd/RAM_tb.vcd");
        $dumpvars();
        if (`D_DEPTH < 24)
            $monitor("%0d: add=%0h, we=%0b, data=%0h, out=%0h, done=%0b", $time, add, we, data, out, done_flag);

        // initial state
        clk = 0;
        rclk = 0;
        res = 0;
        #`T_CLK res = 1;
        #`T_CLK res = 0;
        // wait half phase in order to send steady signals before posedge
        #`T_WR;
        add = 0;
        data = 0;
        we = 0;
        re = 0;

        $display("*** Test stuck at 1's ***");
        for (i = 0; i < `D_DEPTH; i = i + 1) begin
            w_op(i, 0);
            r_op(i, 0);
        end
        check_ram();

        $display("*** Test registers for stuck at 0 ***");
        for (i = 0; i < `D_DEPTH; i = i + 1) begin
            $display("*** Checking stuck at 0 register %0h ***", i);
            for (j = 0; j < `D_WIDTH; j = j + 1) begin
                w_op(i, 2**j);
                r_op(i, 2**j);
                check_ram();
            end
            w_op(i, 0);
        end

        $display("*** Test stuck at 0's and cross talk ***");
        for (i = 0; i < `D_DEPTH; i = i + 1) begin
            w_op(i, 2**`D_WIDTH - 1);
            r_op(i, 2**`D_WIDTH - 1);
            check_ram();
        end
        
        $display("*** Test logic ***");
        for (i = 0; i < `D_DEPTH; i = i + 1) begin
            w_op(i, `D_DEPTH - 1 - i);
            r_op(i, `D_DEPTH - 1 - i);
            check_ram();
        end

        #`T_CLK $finish;
    end
endmodule
