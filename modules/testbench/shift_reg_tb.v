`include "consts.vh"
`timescale 1ns / 1ns

`define VCD "vcd/shift_reg_tb.vcd"
`define TCLK 5


module shift_reg_tb;
    localparam N = 4;
    integer i;
    integer err = 1'b0;
    integer repeats;

    reg res_n;
    reg clk = 1'b0;
    reg load_en = 1'b0;
    reg en_serial = 1'b0;
    reg en_cyclic = 1'b0;
    reg din_serial;
    reg [N-1:0] load;
    wire [N-1:0] out_parallel;
    wire out_serial, out_cyclic;

    shift_reg #(.N(N)) dut_serial (
        .clk(clk), .res_n(res_n), .load_en(load_en), .load(load),
        .en(en_serial), .din(din_serial), .dout_n(out_serial)
    );

    shift_reg #(.N(N)) dut_cyclic (
        .clk(clk), .res_n(res_n), .load_en(load_en), .load(load),
        .en(en_cyclic), .din(out_cyclic), .dout_n(out_cyclic), .dout(out_parallel)
    );

    always #`TCLK clk = ~clk;

    task expect_serial;
        input integer num;
        input integer in;
        integer exp_out, j;
        begin
            $display("%0t: TEST: din bits = %0b for %0d cycles", $time, in, num);
            exp_out = in << (N-1);
            for (j = 0; j <= num; j = j + 1) begin
                din_serial = in[0];
                @(negedge clk);
                //@(posedge clk) #`T_DELAY_FF;
                if (out_serial === exp_out[0])
                    $display("%0t: OK: out_serial is %0b", $time, out_serial);
                else begin
                    $display("%0t [shift_reg_tb] ERROR: out_serial %0b is not as expected %0b on iteration %0d", $time, out_serial, exp_out[0], j);
                    err = err + 1;
                end
                in = in >> 1;
                exp_out = exp_out >> 1;
            end
        end
    endtask

    task expect_load;
        input integer num;
        input integer in;
        integer exp_out;
        integer j;
        begin
            $display("%0t: TEST parallel load bits = %0b for %0d cycles", $time, in, num);
            load = in;
            @(negedge clk) load_en = 1'b1;
            @(negedge clk) load_en = 1'b0;
            for (j = 0; j < num; j = j + 1) begin
                exp_out = j >= N ? din_serial : in >> j;
                if (out_serial === exp_out[0])
                    $display("%0t: OK: out_serial is %0b", $time, out_serial);
                else begin
                    $display("%0t [shift_reg_tb] ERROR: out_serial %0b is not as expected %0b on iteration %0d", $time, out_serial, exp_out[0], j);
                    err = err + 1;
                end
                @(negedge clk);
            end
        end
    endtask

    task expect_cyclic;
        input integer num;
        input integer in;
        integer exp_out, j;
        begin
            $display("%0t: TEST cyclic shift of %0b for %0d cycles", $time, in, num);
            load = in;
            @(negedge clk) load_en = 1'b1;
            @(negedge clk) load_en = 1'b0;
            for (j = 0; j < num; j = j + 1) begin
                exp_out = (j % N == 0) ? in : exp_out >> 1;
                if (out_cyclic === exp_out[0])
                    $display("%0t: OK: out_cyclic is %0b", $time, out_cyclic);
                else begin
                    $display("%0t [shift_reg_tb] ERROR: out_cyclic %0b is not as expected %0b on iteration %0d", $time, out_cyclic, exp_out[0], j);
                    err = err + 1;
                end
                @(negedge clk);
            end
        end
    endtask
    
    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%0t INFO: load_en=%0b  en_serial=%0b  en_cyclic=%0b", $time, load_en, en_serial, en_cyclic);
        `ifndef GATE_FLOW_OFF
            $display("STAR TEST: GATE FLOW RESET");
        `else
            $display("STAR TEST: DATA FLOW RESET");
        `endif
        res_n = 1'b1;
        @(posedge clk) res_n = 1'b0;
        @(posedge clk) res_n = 1'b1;
        @(negedge clk) en_serial = 1'b1;
        repeats = N*2+1;

        $display("TEST serial input: it takes N cycles for dout to start showing din bits");
        $display("Waiting %0d cycles to verify no stuck bits", repeats);
        //expect_serial(repeats, {N{1'b0}});
        for (i = 0; i <= N; i = i + 1)
            expect_serial(repeats, 2**i - 1);
        expect_serial(repeats, 'b1010);
        expect_serial(repeats, 'b0101);

        $display("TEST parallel input: it takes 1 cycle for dout to output load bits");
        $display("but waiting %0d cycles to verify no stucks", repeats);
        for (i = 0; i <= N; i = i + 1)
            expect_load(repeats, 2**i - 1);
        expect_load(repeats, 4'b1011);
        expect_load(repeats, 4'b0101);
        expect_load(repeats, 4'b1010);
        expect_load(repeats, 4'b1101);
        expect_load(repeats, 4'b0110);

        en_serial = 1'b0;
        en_cyclic = 1'b1;
        expect_cyclic(N*3, 4'b0001);
        expect_cyclic(N*3, 4'b1000);
        expect_cyclic(N*3, 4'b1010);
        expect_cyclic(N*3, 4'b1011);
        expect_cyclic(N*3, 4'b0101);

        $display("TEST: persistent register value. TODO: verify more values!");
        en_cyclic = 1'b0;
        repeat(N) begin
            @(negedge clk);
            if (out_parallel != load) begin
                $display("%0t: ERROR: out_parallel %0b is not as expected %0b", $time, out_parallel, load);
                err = err + 1;
            end
        end

        @(posedge clk) if (err)
            $display("[shift_reg_tb] RESULT: TESTS FAILED: %0d errors occured", err);
        else
            $display("[shift_reg_tb] RESULT: TESTS PASSED");
        $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
