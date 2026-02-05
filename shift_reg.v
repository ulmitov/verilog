/*
    N bit Shift register SIPO/PISO/SISO

f="shift_reg"; m="shift_reg"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.v"
`include "flip_flop.v"
//`define GATEFLOW 1


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
    integer i;
    reg [N-1:0] darr;
    assign dout_n = dout[0];

    `ifdef GATEFLOW
        always @(*) begin
            for (i = 0; i < N; i = i + 1) begin
                if (load_en)
                    darr[i] = load[i];
                else begin
                    if (en)
                        darr[i] = dout[i+1];
                    else
                        darr[i] = dout[i];
                end
            end
            if (~load_en & en) darr[N-1] = din;
        end
        genvar k;
        generate
            for (k = 0; k < N; k = k + 1) begin
                ff_d dff_k ( .clk(clk), .res_n(res_n), .en(1'b1), .din(darr[k]), .Q(dout[k]) );
            end
        endgenerate
    `else
        assign dout = darr;
        always @(posedge clk or negedge res_n) begin
            if (!res_n)
                darr <= 0;
            else if (load_en)
                darr <= load;
            else if (en) begin
                darr[N-1] <= din;
                for (i = N - 2; i >= 0; i = i - 1)
                    darr[i] <= darr[i+1];
            end
        end
    `endif
endmodule
