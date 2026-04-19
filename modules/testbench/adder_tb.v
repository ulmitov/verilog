/* 
    Full adder and comparator testbench
*/
`include "consts.vh"
`timescale 1ns / 100ps


module fast_adder_tb;
    adder_tb #(.FAST_ADDER(1), .VCD("vcd/fast_adder_tb.vcd")) fast_tb();
endmodule


module adder_tb #(parameter FAST_ADDER = 0, parameter N = 4, parameter VCD = "vcd/adder_tb.vcd");
    localparam T_DELAY = `T_DELAY_PD * 3 * N;

    wire [N-1:0] sum;
    wire carry, of, eq, lt, ltu;
    reg [N-1:0] X, Y;
    reg mode, msb;
    reg signed [N:0] sum_s;
    integer j, q, check_c, check_s;

    generate
        if (FAST_ADDER)
            fast_adder #(.n(N)) UUT (.X(X), .Y(Y), .Nadd_sub(mode), .sum(sum), .carry(carry), .overflow(of), .eq(eq), .lt(lt), .ltu(ltu));
        else
            adder #(.n(N)) UUT (.X(X), .Y(Y), .Nadd_sub(mode), .sum(sum), .carry(carry), .overflow(of), .eq(eq), .lt(lt), .ltu(ltu));
    endgenerate

    task check_values;
        input [N-1:0] ex_sum;
        input ex_carry;
    begin
        #T_DELAY msb = of ? carry : sum[N-1];
        sum_s = $signed({msb, sum});
        $display("%8d INFO: X=%4b Y=%4b Nadd_sub=%b: sum=%4d (%4b with sign %0b) overflow=%0b, carry=%0d, eq=%0b, lt=%0b, ltu=%0b", $time, X, Y, mode, sum_s, sum, msb, of, carry, eq, lt, ltu);
        if (sum !== ex_sum)
            $display("*** ERROR: sum %0d (%0b) is not equal to expected %0d", sum, sum, ex_sum);
        if (carry != ex_carry)
            $display("*** ERROR: carry %0b is not equal to expected %0b", carry, ex_carry);
    end
    endtask

    task check_flags;
        input ex_overflow;
        input ex_eq;
        input ex_lt;
        input ex_ltu;
    begin
        if (of != ex_overflow)
            $display("*** ERROR: overflow %0b is not equal to expected %0d", of, ex_overflow);
        if (eq != ex_eq)
            $display("*** ERROR: eq %0b is not equal to expected %0b", of, ex_eq);
        if (lt != ex_lt)
            $display("*** ERROR: lt %0b is not equal to expected %0b", of, ex_lt);
        if (ltu != ex_ltu)
            $display("*** ERROR: ltu %0b is not equal to expected %0b", of, ex_ltu);
    end
    endtask

    initial begin
        $dumpfile(VCD);
        $dumpvars(0);
        $monitor("%8d: overflow=%0b  carry=%0b", $time, of, carry);
        $display("Propagation delay = %0d", T_DELAY);

        // Per stage test
        for (j = 0; j < N; j = j + 1) begin

            $display("Test stuck at 1's");
            X = 0; Y = 0; mode = 0; // 0 is addition
            check_values(0, 0);

            $display("Test per stage %0d. q is per stage inputs X, Y. Checking each FA bit by bit.", j);
            for (q = 1; q < 2**N - 1; q = q + 1) begin
                if (j == 0)
                    {X[j], Y[j]} = q[1:0];
                else begin
                    Y[j-1] = 1'b1;
                    {X[j-1], X[j], Y[j]} = q;
                end
                check_s = X + Y;
                check_c = check_s > 2**N - 1;
                check_s = check_s[N-1:0];
                check_values(check_s, check_c);
            end
        end

        $display("Test crosstalk");
        X = 2**N - 1; Y = 2**N - 1; mode = 0;
        check_values(2**N - 2, 1);

        X = -1; Y = -1; mode = 0;
        check_values(-2, 1);

        $display("Test subtraction: N bits represent values 2**%0d/2...-2**%0d/2+1", N, N);
        $display("Checking all cases as signed numbers");
        $display("So we have only N-1 bits to represent magnitude");
        $display("If overflow=1: then sign is the carry");
        $display("If overflow=0: then sign is the MSB (Sn-1) and carry ignored");
        $display("For subtraction: not checking carry if overflow");
        
        X = -7; Y = -2; mode = 0;
        check_values(-9, 1'b1);

        X = 0; Y = 1; mode = 1;
        check_values(-1, 1'b0);
        check_flags(0, 0, 1, 1);

        X = 2**N - 1; Y = 1; mode = 1;
        check_values(-2, 1'b1);
        check_flags(1'b0, 0, 1, 0);

        X = -1; Y = 1; mode = 1;
        check_values(-2, 1'b1);
        check_flags(1'b0, 0, 1, 0);

        X = 2**N - 1; Y = 2**N - 1; mode = 1;
        check_values(0, 1'b1);
        check_flags(1'b0, 1, 0, 0);

        X = 0; Y = 2**N - 1; mode = 1;
        check_values(1, 1'b0);
        check_flags(1'b0, 0, 0, 1);

        $display("Test comparator");
        $display("Same sign for both, X > Y: expect carry 1:");
        X = 4; Y = 3; mode = 1;
        check_values(1, 1'b1);
        check_flags(1'b0, 0, 0, 0);

        X = -3; Y = -4; mode = 1;
        check_values(1, 1'b1);
        check_flags(1'b0, 0, 0, 0);

        $display("Same sign for both, X < Y: expect carry 0:");
        X = 3; Y = 4; mode = 1;
        check_values(-1, 1'b0);
        check_flags(1'b0, 0, 1, 1);

        X = -4; Y = -3; mode = 1;
        check_values(-1, 1'b0);
        check_flags(1'b0, 0, 1, 1);

        $display("Different signs: X > Y: expect carry 0");
        X = 4; Y = -3; mode = 1;
        check_values(7, 1'b0);
        check_flags(1'b0, 0, 0, 1);

        X = 3; Y = -4; mode = 1;
        check_values(7, 1'b0);
        check_flags(1'b0, 0, 0, 1);

        $display("Different signs: X < Y: expect carry 1");
        X = -4; Y = 3; mode = 1;
        check_values(-7, 1'b1);
        check_flags(1'b0, 0, 1, 0);

        X = -3; Y = 4; mode = 1;
        check_values(-7, 1'b1);
        check_flags(1'b0, 0, 1, 0);

        $display("Test comparator with overflow (should be same)");
        $display("Different signs: X > Y: expect carry 0");
        X = 4; Y = -5; mode = 1;
        check_values(9, 1'b0);
        check_flags(1'b1, 0, 0, 1);

        X = 6; Y = -5; mode = 1;
        check_values(11, 1'b0);
        check_flags(1'b1, 0, 0, 1);

        $display("Different signs: X < Y: expect carry 1");
        X = -5; Y = 7; mode = 1;
        check_values(-12, 1'b1);
        check_flags(1'b1, 0, 1, 0);

        X = -7; Y = 3; mode = 1;
        check_values(-10, 1'b1);
        check_flags(1'b1, 0, 1, 0);

        $display("End of testbench: %s", VCD);
        $finish;
    end
endmodule

