/*
    Up-Down N-bit counter with sync reset, enable bit, pre-load value

f="counter"
m="counter"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter #(parameter n = 3) (
    input clk,
    input res_n,
    input up_down,
    input enable,
    input load,
    input [n-1:0] set,
    output reg [n-1:0] count
);
    always @(posedge clk) begin
        if (!res_n)
            count <= 0;
        else if (load)
            count <= set;
        else if (enable)
            count <= count + (up_down ? 1 : -1);
    end
endmodule
