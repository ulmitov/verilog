/*
    N bit Shift register SIPO/PISO/SISO

f="shift_reg"; m="shift_reg"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.v"
`include "flip_flop.v"


module shift_reg #(parameter N = 4) (
    input clk,
    input res_n,
    input en,
    input din,                  // Serial In
    input load_en,              // Parallel load enable
    input [N-1:0] load,         // Parallel load value
    output wire [N-1:0] dout,   // Parallel Out
    output wire dout_n          // Serial Out
    
);
    wire [N:0] load_mux;
    genvar i;
    generate
        assign dout_n = dout[0];
        assign load_mux[N] = din;

        for (i = 0; i < N; i = i + 1) begin
            assign load_mux[i] = load_en ? load[i] : dout[i];
            ff_d dff_i(.clk(clk), .res_n(res_n), .en(en), .din(load_mux[i+1]), .Q(dout[i]));
        end
    endgenerate
endmodule
