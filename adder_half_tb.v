`timescale 1ns / 1ps


module adder_half_tb;
    parameter DELAY = 10;
    parameter USE_CASE = 0;
    reg a, b;
    wire sum, carry;
    wire es, ec;

    generate
        if (USE_CASE)
            adder_half_gateflow adder_half_dut (.a(a), .b(b), .sum(sum), .carry(carry));
        else
            adder_half_dataflow adder_half_dut (.a(a), .b(b), .sum(sum), .carry(carry));
    endgenerate
  
    `define _APPLY_VALUES(x, y) \
    begin \
        a = x; \
        b = y; \
        #DELAY if ((sum) !== (es) || (carry) !== (ec)) \
            $display("ERROR: sum %d !== %d || carry %d !== %d", sum, es, carry, ec); \
    end

    // expected results
    assign ec = a&b;
    assign es = a^b;

    initial begin
        $dumpfile("results/adder_half_tb.vcd");
        $dumpvars(0, adder_half_tb);
        $display("Starting simulation... USE_CASE=%0d", USE_CASE);
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
        #10 $finish;
    end
endmodule
