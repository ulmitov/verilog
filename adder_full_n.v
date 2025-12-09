
module adder_full_n(X, Y, Cin, sum, carry);
parameter n = 4;
input Cin;
input [n-1:0] X, Y;
output reg [n-1:0] sum;
output reg carry;
reg [n:0] C;
integer k;

always @(X, Y, Cin) begin
    C[0] = Cin;
    for (k = 0; k < n; k++) begin
        sum[k] = X[k] ^ Y[k] ^ C[k];
        C[k + 1] = (X[k] & Y[k]) | (X[k] & C[k]) | (Y[k] & C[k]);
    end
    carry = C[n];
end
endmodule


module full_adder_signed(X, Y, Cin, sum, carry, overflow);
    parameter n = 32;
    input Cin;
    input [n-1:0] X, Y;
    output reg [n-1:0] sum;
    output reg carry, overflow;
    
    always @(X, Y, Cin) begin
        {carry, sum} = X + Y + Cin;
        //sum = X ^ Y;
        //carry = (X & Y) | (X & Cin) | (Y & Cin);
        //overflow = (X[n-1] & Y[n-1] & ~S[n-1]) | (~X[n-1] & ~Y[n-1] & S[n-1]);
        overflow = X[n-1] & Y[n-1] & ~sum[n-1];
    end
endmodule
/*
f="adder_full_n"
m="full_adder_signed"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; flatten; opt; fsm; opt; memory; opt; techmap; opt; share -aggressive; dfflibmap -liberty NangateOpenCellLibrary_typical.lib; abc -liberty NangateOpenCellLibrary_typical.lib; clean; stat; write_verilog -noattr ${f}_synth.v; show -format svg -prefix ${f}_${m} ${m}; show ${m}"
*/
/*
module full_adder_signed_3(X, Y, Cin, sum, carry, overflow);
    parameter n = 3;
    input Cin;
    input [n-1:0] X, Y;
    output reg [n-1:0] sum;
    output wire carry, overflow;

    full_adder_signed UUT3(X, Y, Cin, sum, carry, overflow);
    defparam UUT3.n = n;
endmodule
*/

