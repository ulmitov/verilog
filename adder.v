/*
    FULL ADDERs and HALF ADDERs

For unsigned addtition if sum is bigger than bits size, then carry bit will rise!
For signed addition or substraction MSB is the sign bit, but if sum is bigger than bits number,
then overflow will rise and the carry bit will hold the sign fo the sum!
Then, a program instruction that specifies unsigned operands can use the carry-out signal,
while an instruction that has signed operands can use the overflow signal.
*/
/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */
`include "consts.v"


/*
    N bit FULL ADDER and Comparator - max delay is N bits * FA delay (N*3 gates)

f="adder"; m="adder"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; techmap; clean; opt; clean -purge; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module adder #(parameter n = 4) (
    input Nadd_sub,             // Mode select: 0 = addition; 1 = substraction
    input [n-1:0] X,
    input [n-1:0] Y,
    output wire [n-1:0] sum,
    output wire carry,
    output wire overflow,
    output wire eq,
    output wire lt,
    output wire ltu
);
    wire same_sign, cmp;
    `ifdef GATEFLOW
        // ripple carry adder
        wire [n:0] C;
        genvar k;

        assign C[0] = Nadd_sub;

        generate
            for (k = 0; k < n; k = k + 1) begin
                full_adder fa_k (.a(X[k]), .b(Y[k] ^ Nadd_sub), .cin(C[k]), .sum(sum[k]), .carry(C[k+1]));
            end
        endgenerate
    `else
        // Fast adder. Predicting carry using the generation function of x[k] & y[k]
        reg [n:0] C;
        reg [n-1:0] y2c, s;
        integer k;

        assign sum = s;

        always @(*) begin
            C[0] = Nadd_sub;
            for (k = 0; k < n; k = k + 1) begin
                y2c[k] = Y[k] ^ Nadd_sub;
                s[k] = X[k] ^ y2c[k] ^ C[k];
                C[k + 1] = (X[k] & y2c[k]) | ((X[k] + y2c[k]) & C[k]);
            end
        end
    `endif

    assign same_sign = X[n-1] ^ Y[n-1];
    assign carry = C[n];
    assign overflow = C[n-1] ^ C[n];        // alternative: X[n-1] & Y[n-1] & ~sum[n-1];
    assign eq = Nadd_sub & ~(|sum);         // Equality
    assign cmp = Nadd_sub & ~eq;
    assign ltu = cmp & ~carry;   // Less Than unsigned. alternative: ~sum[n-1];
    assign lt = cmp & ((~same_sign & ~carry) | (same_sign & carry)); // Less Than signed
endmodule


/*
N bit FULL ADDER (ripple carry)

f="adder_full_n"
m="adder_full_n"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; flatten; techmap; clean; splitnets -ports; opt; clean -purge; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module adder_full_n #(parameter n = 4) (
    input [n-1:0] X,
    input [n-1:0] Y,
    input Cin,
    output reg [n-1:0] sum,
    output reg carry
);
    reg [n:0] C;
    integer k;

    always @(X, Y, Cin) begin
        C[0] = Cin;
        for (k = 0; k < n; k = k + 1) begin
            sum[k] = X[k] ^ Y[k] ^ C[k];
            C[k + 1] = (X[k] & Y[k]) | (X[k] & C[k]) | (Y[k] & C[k]);
        end
        carry = C[n];
    end
endmodule


/*
Full Adder: max delay is for carry - 3 gates

f="adder"; m="full_adder"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; techmap; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module full_adder (
    input a,
    input b,
    input cin,
    output wire sum,
    output wire carry
);
    `ifdef GATEFLOW
        wire sum1, c1, c2;
        half_adder h0(.a(a), .b(b), .sum(sum1), .carry(c1));
        half_adder h1(.a(sum1), .b(cin), .sum(sum), .carry(c2));
        or #(`T_DELAY_PD) o1(carry, c1, c2);
    `else
        assign sum = a ^ b ^ cin;
        assign carry = (a & b) | (a & cin) | (b & cin);
    `endif
endmodule


/*
Half Adder: 1 gate delay

f="adder"; m="half_adder"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; techmap; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module half_adder (
    input a,
    input b,
    output wire sum,
    output wire carry
);
    `ifdef GATEFLOW
        and #(`T_DELAY_PD) (carry, a, b);
        xor #(`T_DELAY_PD) (sum, a, b);
    `else
        assign carry = a & b;
        assign sum = a ^ b;
    `endif
endmodule
