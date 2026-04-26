/*
    Testbenches for counter modules
*/
`include "consts.vh"
`timescale 1ns / 1ns


module counter_dff_tb;
    counter_tb #(.TYPE("dff")) cnt_tb();
endmodule

module counter_jkff_tb;
    counter_tb #(.TYPE("jkff")) cnt_tb();
endmodule

module counter_tff_sync_tb;
    counter_tb #(.TYPE("tff_sync")) cnt_tb();
endmodule

module counter_tff_async_tb;
    counter_tb #(.TYPE("tff_async")) cnt_tb();
endmodule


module counter_tb #(parameter N = 4, parameter TYPE = "dff");
    localparam T_CLK = `T_DELAY_FF * N + 1;
    localparam T_CYC = T_CLK * 2;
    localparam TDELAY = `T_DELAY_FF + 1;
    parameter vcd = {"vcd/counter_", TYPE, "_tb.vcd"};

    reg clk = 1'b0;
    reg res_n, enable, count_up, load, err;
    reg [N-1:0] set, expected;
    wire [N-1:0] count;
    integer i;

    generate
        if (TYPE == "dff")
            counter #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .load_en(load), .load(set), .count(count));
        else if (TYPE == "jkff")
            counter_jkff #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count)); 
        else if (TYPE == "tff_sync")
            counter_tff_sync #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count));
        else if (TYPE == "tff_async")
            counter_tff_async #(N) dut (.clk(clk), .res_n(res_n), .en(enable), .count(count));
    endgenerate
    
    always #T_CLK clk = ~clk;

    always @(negedge clk) begin
        if (expected !== 'bX && expected !== count) begin
            $error("[%0t] [counter_tb]: count=%0d not as expected %0d", $time, count, expected);
            err <= 1'b1;
        end else err <= 1'b0;
    end

    initial begin
        $dumpfile(vcd);
        $dumpvars(0);
        $monitor("%0d: en=%0d count=%0d expected=%0d", $time, enable, count, expected);
        
        $display("*** TC init TYPE = %s ***", TYPE);
        count_up = 1'b1;
        enable = 1'b0;
        res_n = 1'b1;
        #T_CYC res_n = 1'b0;
        load = 1'b0;
        #T_CYC res_n = 1'b1;
        enable = 1'b1;
        expected = 0;

        $display("*** TC count up ***");
        for (i = 0; i < 2*2**N - 2; i = i + 1) begin
            #T_CYC expected = (expected == 2**N - 1) ? 0 : expected + 1;
            
        end

        if (TYPE != "tff_async") begin
            $display("*** TC count down ***");
            enable = 1'b0;
            count_up = 1'b0;
            #T_CYC enable = 1'b1;
            for (i = 0; i < 2*2**N; i = i + 1) begin
                #T_CYC expected = expected == 0 ? 2**N - 1 : expected - 1;
            end
        end

        $display("*** TC disabled state ***");
        enable = 1'b0;
        for (i = 0; i < 2**N; i = i + 1) #T_CYC;
        enable = 1'b1;

        if (TYPE == "dff") begin
            $display("*** TC set load to 1's ***");
            load = 1'b1;
            set = 2**N >> 1;
            #T_CYC expected = set;
            set = 2**N - 1;
            #T_CYC expected = set;
            #T_CYC load = 1'b0;
            
            for (i = 0; i < 2**N >> 1; i = i + 1) begin
                #T_CYC expected = expected == 0 ? 2**N - 1 : expected - 1;
                
            end
            $display("*** TC set load to 0's ***");
            set = 0;
            load = 1'b1;
            #T_CYC expected = set;
            count_up = 1'b1;
            #T_CYC load = 1'b0;
            for (i = 0; i < 2**N >> 1; i = i + 1) begin
                #T_CYC expected = expected + 1;
            end
            
        end

        enable = 1'b0;
        $display("End of testbench: %s", vcd);
        $finish;
    end
endmodule
