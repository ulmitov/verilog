/*
    N bit Shift register SIPO/PISO/SISO

f="shift_reg"; m="shift_reg"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.vh"
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
    reg [N-1:0] darr;
    integer i;

    assign dout_n = dout[0];

    `ifndef GATE_FLOW_OFF
        always @(*) begin
            for (i = 0; i < N; i = i + 1) begin
                if (load_en)
                    darr[i] = load[i];
                else begin
                    // mux on inputs
                    if (en) begin
                        if (i == N-1)
                            darr[i] = din;          // MSB FF input is din
                        else
                            darr[i] = dout[i+1];    // each FF input is the output of the preceding FF
                    end else
                        darr[i] = dout[i];          // each FF input is the output of current FF
                end
            end
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
            if (~res_n)
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


/* Shift register shift out MSB first, recieve into LSB */
module shift_reg_msb #(parameter N = 4) (
    input clk,
    input res_n,
    input en,
    input din,                  // Serial In
    input load_en,              // Parallel load enable
    input [N-1:0] load,         // Parallel load value
    output wire [N-1:0] dout,   // Parallel Out
    output wire dout_n          // Serial Out
);
    reg [N-1:0] darr;
    integer i;

    assign dout_n = dout[N-1];

    `ifndef GATE_FLOW_OFF
        always @(*) begin
            for (i = 0; i < N; i = i + 1) begin
                if (load_en)
                    darr[i] = load[i];
                else if (~en)
                    darr[i] = dout[i];
                else if (i == 0)
                    darr[i] = din;
                else
                    darr[i] = dout[i-1];
            end
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
            if (~res_n)
                darr <= 0;
            else if (load_en)
                darr <= load;
            else if (en) begin
                darr[0] <= din;
                for (i = 1; i < N; i = i + 1)
                    darr[i+1] <= darr[i];
            end
        end
    `endif
endmodule
