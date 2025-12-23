/*
    2 bit HALF ADDER
    3 bit FULL ADDER

f="adder_half"
m="adder_half_dataflow"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; techmap; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module adder_half_dataflow (
    input a,
    input b,
    output sum,
    output carry
);
    specify
        // Specparam declaration to define timing parameters
        specparam TholdA = 3;
        specparam TholdB = 2;

        // Path declarations to specify delays between signals
        (a *> sum) = TholdA;   // Delay from input 'a' to output 'out': Full connection
        (b => carry) = TholdB;   // Delay from input 'b' to output 'out': Parallel connection
    endspecify

    assign carry = a & b;
    assign sum = a ^ b;
endmodule


module adder_half_gateflow (
    input a,
    input b,
    output sum,
    output carry
);
    and (carry, a, b);
    xor (sum, a, b);
endmodule


module adder_full(sum, carry, a, b, cin);
    input a, b, cin;
    output sum, carry;
    // internal values
    wire sum1, carry1, carry2;

    adder_half_dataflow h0(sum1, carry1, a, b);
    adder_half_dataflow h1(sum, carry2, sum1, cin);
    or o1(carry, carry1, carry2);
endmodule


module adder_full_dataflow(sum, carry, a, b, cin);
    input a, b, cin;
    output sum, carry;
    assign sum = a ^ b ^ cin;
    assign carry = (a & b) | (a & cin) | (b & cin);
endmodule
