`include "consts.v"

`timescale 1ns / 1ns;


module counter_tb();
    parameter n = 4;
    parameter T_CLK = `T_FF_DELAY * n + 1;
    parameter T_CYC = T_CLK * 2;
    parameter TYPE = "tff_async";
    parameter vcd = {"results/counter_", TYPE, "_tb.vcd"};

    reg res_n, enable, count_up, load;
    reg clk = 1'b0;
    reg [n-1:0] set;
    wire [n-1:0] count;
    integer i, expected;

    generate
        if (TYPE == "behavioral")
            counter_behavioral #(n) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .load(load), .set(set), .count(count));
        else if (TYPE == "jkff")
            counter_jkff #(n) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count)); 
        else if (TYPE == "tff_sync")
            counter_tff_sync #(n) dut (.clk(clk), .res_n(res_n), .en(enable), .count_up(count_up), .count(count));
        else if (TYPE == "tff_async")
            counter_tff_async #(n) dut (.clk(clk), .res_n(res_n), .en(enable), .count(count));
    endgenerate
    
    always #T_CLK clk = ~clk;

    always #T_CYC if (expected !== count)
        $display("ERROR: %0d: count=%0d not as expected %0d", $time, count, expected);

    initial begin
        $dumpfile(vcd);
        $dumpvars(0, counter_tb);
        $monitor("%0d: set=%0b, en=%0d res_n=%0d, count=%0d", $time, set, enable, res_n, count);
        
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
        for (i = 0; i < 2*2**n - 2; i = i + 1) begin
            expected = expected == 2**n - 1 ? 0 : expected + 1;
            #T_CYC;
        end

        if (TYPE != "tff_async") begin
            $display("*** TC count down ***");
            enable = 1'b0;
            count_up = 1'b0;
            #T_CYC enable = 1'b1;
            for (i = 0; i < 2*2**n; i = i + 1) begin
                expected = expected == 0 ? 2**n - 1 : expected - 1;
                #T_CYC;
            end
        end

        $display("*** TC disabled state ***");
        enable = 1'b0;
        for (i = 0; i < 2**n; i = i + 1) #T_CYC;
        enable = 1'b1;

        if (TYPE == "behavioral") begin
            $display("*** TC set load ***");
            load = 1'b1;
            set = 2**n - 1;
            expected = set;
            #T_CYC set = 0;
            load = 1'b0;
            for (i = 0; i < 2**n; i = i + 1) begin
                expected = expected == 0 ? 2**n - 1 : expected - 1;
                #T_CYC;
            end
        end
        enable = 1'b0;
        #T_CYC $display("FINISHED: %s", vcd);
        $finish;
    end
endmodule
