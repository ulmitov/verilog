`timescale 1ns / 1ns;


module adder_full_n_tb();
    parameter n = 8;
    parameter DELAY = 5;
    reg Cin;
    reg [n-1:0] X, Y;
    wire [n-1:0] sum;
    wire carry;
    integer j, q, check_s, check_c;

    adder_full_n #(.n(n)) UUT(.X(X), .Y(Y), .Cin(Cin), .sum(sum), .carry(carry));

    initial begin
        $dumpfile("results/adder_full_n_tb.vcd");
        $dumpvars(0, adder_full_n_tb);
        $display("Test start");

        // Per stage test
        for (j = 0; j < n; j = j + 1) begin

            // test stuck at 1's
            X = 0; Y = 0; Cin = 0;
            #DELAY;
            if (sum[j] !== 0)
                $display("ERROR: sum %d is not equal to 0", sum);
            if (carry !== 0)
                $display("ERROR: carry %d is not equal to 0", carry);

            // test all paths per stage
            $display("Testing stage %d", j);
            for (q = 3'b001; q < 3'b111; q = q + 1) begin
                if (j == 0)
                    {Cin, X[j], Y[j]} = q;
                else
                    Y[j-1] = 1'b1;
                    {X[j-1], X[j], Y[j]} = q;
                if (q == 1 || q == 2 || q == 4) begin
                    check_s = 1;
                    check_c = 0;
                end else begin
                    check_s = 0;
                    check_c = 1;
                end
                #DELAY $display("%0d %0d: %8b: X=%b Y=%b %b: sum[%0d]=%d sum[j+1]=%d carry=%d (SUM=%d)", $time, j, q, X, Y, Cin, j, sum, sum[j+1], carry, sum);
                if (sum[j] !== check_s)
                    $display("%d %d: %b: ERROR: sum[%0d] %d is not equal to %d", $time, j, q, j, sum, check_s);
                if ((j < n-1 && sum[j+1] !== check_c) || (j == n-1 && carry !== check_c))
                    $display("%d %d: %b: ERROR: carry %d is not equal to %d", $time, j, q, sum[j+1], check_c);
            end
        end

        // test crosstalk
        X = 2**n - 1; Y = 2**n - 1; Cin = 1;
        #DELAY;
        if (sum !== 2**n - 1)
            $display("ERROR: sum %d is not equal to %d", sum, 2**n - 1);
        if (carry !== 1)
            $display("ERROR: carry %d is not equal to 1", carry);
        $display("%0d X=%b Y=%b %b: sum=%d carry=%d", $time, X, Y, Cin, sum, carry);
        $display("Test end");
        $finish;
    end
endmodule
