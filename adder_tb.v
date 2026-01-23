/* Full adder and comparator testbench */
`include "consts.v"
`timescale 1ns / 100ps

/*
#signed add: addi t0, t1, +imm; blt t0, t1, overflow.
#unsigned add: add t0, t1, t2; bltu t0, t1, overflow.
*/
module adder_tb();
    localparam n = 4;
    localparam T_DELAY = `T_DELAY_PD * 3 * n;

    wire [n-1:0] sum;
    wire carry, of, eq, lt, ltu;
    reg [n-1:0] X, Y;
    reg mode, msb;
    reg signed [n:0] sum_s;

    integer j, q, check_c, check_s;

    adder #(.n(n)) UUT (.X(X), .Y(Y), .Nadd_sub(mode), .sum(sum), .carry(carry), .overflow(of), .eq(eq), .lt(lt), .ltu(ltu));

    task check_values;
        input [n-1:0] ex_sum;
        input ex_carry;
        input ex_overflow;
        input ex_eq;
        input ex_lt;
        input ex_ltu;
    begin
        #T_DELAY if (of)
            msb = carry;
        else
            msb = sum[n-1];
        sum_s = $signed({msb, sum});
        $display("%8d INFO: X=%4b Y=%4b Nadd_sub=%b: sum=%4d (%4b with sign %0b) overflow=%0b, carry=%0d, eq=%0b, lt=%0b, ltu=%0b", $time, X, Y, mode, sum_s, sum, msb, of, carry, eq, lt, ltu);
        if (sum !== ex_sum)
            $display("*** ERROR: sum %0d (%0b) is not equal to expected %0d", sum, sum, ex_sum);
        if (carry != ex_carry)
            $display("*** ERROR: carry %0b is not equal to expected %0b", carry, ex_carry);
        if (of != ex_overflow)
            $display("*** ERROR: overflow %0b is not equal to expected %0b", of, ex_overflow);
        if (eq != ex_eq)
            $display("*** ERROR: eq %0b is not equal to expected %0b", of, ex_eq);
        if (lt != ex_lt)
            $display("*** ERROR: lt %0b is not equal to expected %0b", of, ex_lt);
        if (ltu != ex_ltu)
            $display("*** ERROR: ltu %0b is not equal to expected %0b", of, ex_ltu);
    end
    endtask

    initial begin
        $dumpfile("vcd/adder_tb.vcd");
        $dumpvars();
        $display("Test start");

        // Per stage test
        for (j = 0; j < n; j = j + 1) begin

            $display("Test stuck at 1's");
            X = 0; Y = 0; mode = 0;
            check_values(0, 0, 0, 1'bX, 1'bX, 1'bX);

            $display("Test per stage %0d. q is per stage inputs X, Y. Checking each FA bit by bit.", j);
            for (q = 1; q < 2**n - 1; q = q + 1) begin
                if (j == 0)
                    {X[j], Y[j]} = q[1:0];
                else begin
                    Y[j-1] = 1'b1;
                    {X[j-1], X[j], Y[j]} = q;
                end
                check_s = X + Y;
                check_c = check_s > 2**n - 1;
                check_s = check_s[n-1:0];
                check_values(check_s, check_c, 1'bX, 1'bX, 1'bX, 1'bX);
            end
        end

        $display("Test crosstalk");
        X = 2**n - 1; Y = 2**n - 1; mode = 0;
        check_values(2**n - 2, 1, 0, 1'bX, 1'bX, 1'bX);

        X = -1; Y = -1; mode = 0;
        check_values(-2, 1, 0, 1'bX, 1'bX, 1'bX);

        $display("Test substraction: N bits represent values 2**%0d/2...-2**%0d/2+1", n, n);
        $display("Checking all cases as signed numbers");
        $display("So we have only N-1 bits to represent magnitude");
        $display("If overflow=1: then sign is the carry");
        $display("If overflow=0: then sign is the MSB (Sn-1) and carry ignored");
        $display("For substarction: not checking carry if overflow");
        
        X = -7; Y = -2; mode = 0;
        check_values(-9, 1'b1, 1'b1, 1'bX, 1'bX, 1'bX);

        X = 0; Y = 1; mode = 1;
        check_values(-1, 1'bX, 1'b0, 0, 1, 1);

        X = 2**n - 1; Y = 1; mode = 1;
        check_values(-2, 1'bX, 1'b0, 0, 1, 0);

        X = -1; Y = 1; mode = 1;
        check_values(-2, 1'bX, 1'b0, 0, 1, 0);

        X = 2**n - 1; Y = 2**n - 1; mode = 1;
        check_values(0, 1'bX, 1'b0, 1, 0, 0);

        X = 0; Y = 2**n - 1; mode = 1;
        check_values(1, 1'bX, 1'b0, 0, 0, 1);

        $display("Test comparator");
        $display("Same sign for both, X > Y: expect carry 1:");
        X = 4; Y = 3; mode = 1;
        check_values(1, 1'b1, 1'b0, 0, 0, 0);

        X = -3; Y = -4; mode = 1;
        check_values(1, 1'b1, 1'b0, 0, 0, 0);

        $display("Same sign for both, X < Y: expect carry 0:");
        X = 3; Y = 4; mode = 1;
        check_values(-1, 1'b0, 1'b0, 0, 1, 1);

        X = -4; Y = -3; mode = 1;
        check_values(-1, 1'b0, 1'b0, 0, 1, 1);

        $display("Different signs: X > Y: expect carry 0");
        X = 4; Y = -3; mode = 1;
        check_values(7, 1'b0, 1'b0, 0, 0, 1);

        X = 3; Y = -4; mode = 1;
        check_values(7, 1'b0, 1'b0, 0, 0, 1);

        $display("Different signs: X < Y: expect carry 1");
        X = -4; Y = 3; mode = 1;
        check_values(-7, 1'b1, 1'b0, 0, 1, 0);

        X = -3; Y = 4; mode = 1;
        check_values(-7, 1'b1, 1'b0, 0, 1, 0);

        $display("Test comparator with overflow (should be same)");
        $display("Different signs: X > Y: expect carry 0");
        X = 4; Y = -5; mode = 1;
        check_values(9, 1'b0, 1'b1, 0, 0, 1);

        X = 6; Y = -5; mode = 1;
        check_values(11, 1'b0, 1'b1, 0, 0, 1);

        $display("Different signs: X < Y: expect carry 1");
        X = -5; Y = 7; mode = 1;
        check_values(-12, 1'b1, 1'b1, 0, 1, 0);

        X = -7; Y = 3; mode = 1;
        check_values(-10, 1'b1, 1'b1, 0, 1, 0);

        $finish;
    end
endmodule


module half_adder_tb;
    localparam T_DELAY = `T_DELAY_PD * 2;
    reg a, b;
    wire sum, carry;
    wire es, ec;

    half_adder ha_dut (.a(a), .b(b), .sum(sum), .carry(carry));
  
    `define _APPLY_VALUES(x, y) \
    begin \
        a = x; \
        b = y; \
        #T_DELAY if ((sum !== es) || (carry !== ec)) \
            $display("ERROR: sum %d !== %d || carry %d !== %d", sum, es, carry, ec); \
    end

    // expected results
    assign ec = a&b;
    assign es = a^b;

    initial begin
        $dumpfile("vcd/adder_half_tb.vcd");
        $dumpvars(0, half_adder_tb);
        $monitor("%d (a, b)=(%b, %b), sum,carry=(%b, %b), exp=(%b, %b)", $time, a, b, sum, carry, es, ec);
        `_APPLY_VALUES(0, 0);
        `_APPLY_VALUES(0, 1);
        `_APPLY_VALUES(1, 0);
        `_APPLY_VALUES(1, 1);
        `_APPLY_VALUES(0, 1);
        `_APPLY_VALUES(1, 0);
        `_APPLY_VALUES(1, 1);
        `_APPLY_VALUES(0, 1);
        `_APPLY_VALUES(0, 0);
        $finish;
    end
endmodule
