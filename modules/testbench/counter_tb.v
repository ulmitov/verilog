/*
    Testbench for different counters
*/
`include "consts.vh"
`timescale 1ns / 1ns


module counter_tb();
    parameter N = 4;
    parameter T_CLK = `T_DELAY_FF * N + 1;
    parameter T_CYC = T_CLK * 2;

    parameter TYPE = "behavioral";
    parameter vcd = {"vcd/counter_", TYPE, "_tb.vcd"};

    reg res_n, enable, count_up, load;
    reg clk = 1'b0;
    reg [N-1:0] set;
    wire [N-1:0] count;
    integer i, expected;

    generate
        if (TYPE == "behavioral")
            counter_behavioral #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .load(load), .set(set), .count(count));
        else if (TYPE == "jkff")
            counter_jkff #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count)); 
        else if (TYPE == "tff_sync")
            counter_tff_sync #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count));
        else if (TYPE == "tff_async")
            counter_tff_async #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count(count));
    endgenerate
    
    always #T_CLK clk = ~clk;

    always #T_CYC if (expected !== 'bX && expected !== count)
        $display("[counter_tb] ERROR: %0d: count=%0d not as expected %0d", $time, count, expected);

    initial begin
        $dumpfile(vcd);
        $dumpvars(0);
        $monitor("%0d: en=%0d count=%0d", $time, enable, count);
        
        $display("*** TC init TYPE = %s ***", TYPE);
        count_up = 1'b1;
        enable = 1'b0;
        res_n = 1'b1;
        #T_CYC res_n = 1'b0;
        load = 1'b0;
        expected = 0;
        #T_CYC res_n = 1'b1;
        enable = 1'b1;

        $display("*** TC count up ***");
        for (i = 0; i < 2*2**N - 2; i = i + 1) begin
            expected = (expected == 2**N - 1) ? 0 : expected + 1;
            #T_CYC;
        end

        if (TYPE != "tff_async") begin
            $display("*** TC count down ***");
            enable = 1'b0;
            count_up = 1'b0;
            #T_CYC enable = 1'b1;
            for (i = 0; i < 2*2**N; i = i + 1) begin
                expected = expected == 0 ? 2**N - 1 : expected - 1;
                #T_CYC;
            end
        end

        $display("*** TC disabled state ***");
        enable = 1'b0;
        for (i = 0; i < 2**N; i = i + 1) #T_CYC;
        enable = 1'b1;

        if (TYPE == "behavioral") begin
            $display("*** TC set load to 1's ***");
            load = 1'b1;
            set = 2**N - 1;
            expected = set;
            #T_CYC set = 0;
            $display("*** TC set load to 0's ***");
            load = 1'b0;
            for (i = 0; i < 2**N; i = i + 1) begin
                expected = expected == 0 ? 2**N - 1 : expected - 1;
                #T_CYC;
            end
        end
        enable = 1'b0;
        $display("End of testbench: %s", vcd);
        $finish;
    end
endmodule
