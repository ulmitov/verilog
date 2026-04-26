/*
tb="half_adder_tb"; verilator --lint-only -Wall adder.v
iverilog -Wall -g2005 -gspecify -o ./vcd/${tb}.vvp -s ${tb} testbench/${tb}.v adder.v && vvp ./vcd/${tb}.vvp
*/
`include "consts.vh"
`timescale 1ns / 100ps
`define VCD "vcd/adder_half_tb.vcd"


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
            $error("sum %d !== %d || carry %d !== %d", sum, es, carry, ec); \
    end

    // expected results
    assign ec = a&b;
    assign es = a^b;

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
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
        $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
