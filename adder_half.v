/*
f="adder_half"
m="adder_half_dataflow"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; flatten; opt; techmap; opt; share -aggressive; clean; stat; write_verilog -noattr synth/${f}_synth.v; show -format svg -prefix synth/${f}_${m} ${m}; show ${m}"
*/
module adder_half(output sum, output carry, input a, input b);
    and (carry, a, b);
    xor (sum, a, b);
endmodule


module adder_half_dataflow(output sum, output carry, input a, input b);
    specify
        // Specparam declaration to define timing parameters
        specparam TRiseA = 3; // Rise time delay
        specparam TRiseB = 2; // Fall time delay

        // Path declarations to specify delays between signals
        (a *> sum) = TRiseA;   // Delay from input 'a' to output 'out'/ Full connection
        (b => carry) = TRiseB;   // Delay from input 'b' to output 'out'. Parallel connection

        // System timing checks to enforce timing constraints on signal transitions.
        $setup(a, sum, 55);   // Check setup time for signal 'a' relative to 'out'. 
    endspecify

    assign carry = a&b;
    assign sum = a^b;
endmodule

module adder_full(sum, carry, a, b, cin);
    input a, b, cin;
    output sum, carry;
    // internal values
    wire sum1, carry1, carry2;

    adder_half h0(sum1, carry1, a, b);
    adder_half h1(sum, carry2, sum1, cin);
    or o1(carry, carry1, carry2);
endmodule

module adder_full_data(sum, carry, a, b, cin);
    input a, b, cin;
    output sum, carry;
    assign sum = a ^ b ^ cin;
    assign carry = (a & b) | (a & cin) | (b & cin);
endmodule
