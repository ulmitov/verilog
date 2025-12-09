`timescale 1ns / 1ps

module adder_half_tb;
    parameter DELAY = 10;
    parameter USE_CASE = 0;
    reg a, b;
    wire sum, carry;
    wire es, ec;

    generate
        if (USE_CASE)
          adder_half adder_half_dut (.sum(sum), .carry(carry), .a(a), .b(b));
        else
          adder_half_dataflow adder_half_dut (.sum(sum), .carry(carry), .a(a), .b(b));
    endgenerate
  
    // expected results
    assign ec = a&b;
    assign es = a^b;

    initial begin
        $dumpfile("results/adder_half_tb_test.vcd");
        $dumpvars(0, adder_half_tb);
        $display("Starting simulation... %s", USE_CASE);
        $monitor("%d a=%b, b=%b, sum,carry=(%b, %b), exp=(%b, %b)", $time, a, b, sum, carry, es, ec);
        a = 0; b = 0;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 0; b = 1;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 1; b = 0;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 1; b = 1;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 0; b = 1;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 1; b = 0;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 1; b = 1;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        a = 0;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        b = 0;
        #DELAY if ((sum) !== (es) || (carry) !== (ec))
          $display("ERROR: sum %d !== $d || carry %d !== %d", sum, es, carry, ec);
        #10 $display("End simulation...");
    end
endmodule

