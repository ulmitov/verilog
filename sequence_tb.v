`timescale 1ns / 1ns

module sequence_tb();
    reg clk, reset, data;
    reg [3:0] pass;
    wire out, out2;
    reg OUT;
    reg [31:0] stimulus;
    reg [31:0] result;
    localparam T_CLK = 10;
    localparam T_CYC = T_CLK * 2;
    integer tc_counter = 0;
    integer no_overlapp = 0;
    integer i, fn, expected;

    sequence_detector dut(.clk(clk), .res_n(reset), .seq(pass), .din(data), .dout(out));
    sequence_detector #(0) dut_no(.clk(clk), .res_n(reset), .seq(pass), .din(data), .dout(out2));

    always begin
        #T_CLK clk = ~clk;
        fn = $time / T_CYC;
        OUT = no_overlapp ? out2 : out;
        // each stimulus takes 34 clk phases: 32 bits + reset + post if
        result = result | OUT << (tc_counter * 34 - fn);
    end

    initial begin
        $dumpfile("vcd/sequence_tb.vcd");
        $dumpvars();
        $monitor("%0d: fn=%0d, d=%0d, out=%0d, result=%0b", $time, fn, data, OUT, result);

        clk = 1'b0;

        reset = 0;
        #T_CYC reset = 1;
        result = 0;
        tc_counter = tc_counter + 1;
        pass = 4'b1010;
        stimulus = 32'b01001011101001010110101110101011;
        expected = 32'b100001000010000010100;
        for (i = 32; i > 0; i = i - 1)
            #T_CYC data = stimulus[i - 1];
        #T_CYC if (result != expected)
            $display("%0d: TEST %0d FAILED: got %0b instead of %0b", $time, tc_counter, result, expected);
        else
            $display("%0d: TEST %0d PASSED", $time, tc_counter);

        reset = 0;
        #T_CYC reset = 1;
        result = 0;
        tc_counter = tc_counter + 1;
        pass = 4'b1101;
        stimulus = 32'b01001011101001010110101110110110;
        expected = 32'b1000000000100000100100;
        for (i = 32; i > 0; i = i - 1)
            #T_CYC data = stimulus[i - 1];
        #T_CYC if (result != expected)
            $display("%0d: TEST %0d FAILED: got %0b instead of %0b", $time, tc_counter, result, expected);
        else
            $display("%0d: TEST %0d PASSED", $time, tc_counter);

        reset = 0;
        #T_CYC reset = 1;
        result = 0;
        tc_counter = tc_counter + 1;
        pass = 4'b0110;
        stimulus = 32'b01001010100101011011011011011010;
        expected = 32'b100100100100100;
        for (i = 32; i > 0; i = i - 1)
            #T_CYC data = stimulus[i - 1];
        #T_CYC if (result != expected)
            $display("%0d: TEST %0d FAILED: got %0b instead of %0b", $time, tc_counter, result, expected);
        else
            $display("%0d: TEST %0d PASSED", $time, tc_counter);

        no_overlapp = 1;
        reset = 0;
        #T_CYC reset = 1;
        result = 0;
        tc_counter = tc_counter + 1;
        pass = 4'b0110;
        stimulus = 32'b01001010100101011011011011011010;
        expected = 32'b100000100000100;
        for (i = 32; i > 0; i = i - 1)
            #T_CYC data = stimulus[i - 1];
        #T_CYC if (result != expected)
            $display("%0d: TEST NON-OVERLAPPING %0d FAILED: got %0b instead of %0b", $time, tc_counter, result, expected);
        else
            $display("%0d: TEST NON-OVERLAPPING %0d PASSED", $time, tc_counter);

        reset = 0;
        #T_CYC reset = 1;
        result = 0;
        tc_counter = tc_counter + 1;
        pass = 4'b1101;
        stimulus = 32'b01001010100101011011011011011010;
        expected = 32'b10000010000010;
        for (i = 32; i > 0; i = i - 1)
            #T_CYC data = stimulus[i - 1];
        #T_CYC if (result != expected)
            $display("%0d: TEST NON-OVERLAPPING %0d FAILED: got %0b instead of %0b", $time, tc_counter, result, expected);
        else
            $display("%0d: TEST NON-OVERLAPPING %0d PASSED", $time, tc_counter);
        $finish;
    end
endmodule

/*
The problem is in the testbench. The inputs are not properly synchronized to the clock. You should drive the inputs in the testbench the same way as you drive them inside the design code: use @(posedge clk) and nonblocking assignments (<=) instead of # delays and blocking assignments. Replace your initial block with the following:

initial begin
    reset      = 1;
    test_input = 0;

    repeat (2) @(posedge clk); reset <= 0;

    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 0;
    @(posedge clk) test_input <= 0;
    @(posedge clk) test_input <= 0;
    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 0;
    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 0;
    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 1;
    @(posedge clk) test_input <= 1;

    repeat (3) @(posedge clk);
    $finish;
end

*/