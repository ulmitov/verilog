`include "consts.v"
`timescale 1ns / 1ns

`define T_CLK 5


module shift_reg_tb;
    localparam N = 4;
    integer i;
    integer err = 1'b0;

    reg clk = 1'b0;
    reg res_n = 1'b1;
    reg load_en = 1'b0;
    reg en_serial = 1'b0;
    reg en_cyclic = 1'b0;
    reg din_serial;
    reg [N-1:0] load;
    wire out_serial, out_cyclic;

    shift_reg #(.N(N)) dut_serial (
        .clk(clk), .res_n(res_n), .load_en(load_en), .load(load),
        .en(en_serial), .din(din_serial), .dout(out_serial)
    );

    shift_reg #(.N(N)) dut_cyclic (
        .clk(clk), .res_n(res_n), .load_en(load_en), .load(load),
        .en(en_cyclic), .din(out_cyclic), .dout(out_cyclic)
    );

    always #`T_CLK clk = ~clk;

    task expect_dout;
        input integer num;
        input integer in;
        integer exp_out;
        begin
            $display("%0t: TEST bits %0b for %0d cycles", $time, in, num);
            exp_out = num < N ? in << num : in << N;
            repeat (num) begin
                din_serial = in[0];
                @(posedge clk);
                #`T_DELAY_FF;
                if (out_serial === exp_out[0])
                    $display("%0t: OK: dout is %0b", $time, out_serial);
                else begin
                    $display("%0t: ERROR: dout %0b is not as expected %0b", $time, out_serial, exp_out[0]);
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
        begin
            $display("%0t: TEST parallel load bits %0b for %0d cycles", $time, in, num);
            exp_out = in;
            load_en = 1'b1;
            load = in;
            @(posedge clk) load_en = ~load_en;
            repeat (num) begin
                @(posedge clk);
                #`T_DELAY_FF;
                if (out_serial === exp_out[0])
                    $display("%0t: OK: dout is %0b", $time, out_serial);
                else begin
                    $display("%0t: ERROR: dout %0b is not as expected %0b", $time, out_serial, exp_out[0]);
                    err = err + 1;
                end
                exp_out = exp_out >> 1;
            end
        end
    endtask

    task expect_cyclic;
        input integer num;
        input integer in;
        integer exp_out;
        integer j;
        begin
            $display("%0t: TEST cyclic shift of %0b for %0d cycles", $time, in, num);
            load_en = 1'b1;
            load = in;
            j = 0;
            @(posedge clk) load_en = ~load_en;
            repeat (num) begin
                if (j % N == 0)
                    exp_out = in;
                @(posedge clk);
                #`T_DELAY_FF;
                if (out_cyclic === exp_out[0])
                    $display("%0t: OK: dout is %0b", $time, out_cyclic);
                else begin
                    $display("%0t: ERROR: dout %0b is not as expected %0b", $time, out_cyclic, exp_out[0]);
                    err = err + 1;
                end
                exp_out = exp_out >> 1;
                j = j + 1;
            end
        end
    endtask
    
    initial begin
        $dumpfile("vcd/shift_reg_tb.vcd");
        $dumpvars;
        //$monitor("%0t: din=%0b, dout=%0b", $time, din, out_serial);
        $display("RESET");
        @(posedge clk) res_n = 0;
        @(posedge clk) res_n = 1;
        en_serial = 1'b1;
        $display("TEST serial input: it takes N cycles for dout to start showing din bits");
        $display("waiting N*2 + 1 cycles to verify no stuck bits");
        expect_dout(N*2+1, {N{1'b0}});
        for (i = 1; i <= N; i = i + 1) begin
            expect_dout(N*2+1, 2**i - 1);
        end
        expect_dout(N*2+1, 'b1010);
        expect_dout(N*2+1, 'b0101);

        $display("TEST parallel input: it takes 1 cycle for dout to start showing din bits");
        $display("but waiting N*2 + 1 cycles to verify no stuck bits");
        expect_load(N, 4'b0);
        for (i = 1; i <= N; i = i + 1) begin
            expect_load(N*2+1, 2**i - 1);
        end
        expect_load(N*2+1, 4'b1011);
        expect_load(N*2+1, 4'b0101);
        expect_load(N*2+1, 4'b1010);
        expect_load(N*2+1, 4'b1101);
        expect_load(N*2+1, 4'b0110);

        en_serial = 1'b0;
        en_cyclic = 1'b1;
        expect_cyclic(N*3, 4'b0001);
        expect_cyclic(N*3, 4'b1000);
        expect_cyclic(N*3, 4'b1010);
        expect_cyclic(N*3, 4'b1011);
        expect_cyclic(N*3, 4'b0101);
        @(posedge clk) if (err)
            $display("TEST FAILED: %0d error occured", err);
        else
            $display("TEST PASSED");
        $finish;
    end
endmodule
