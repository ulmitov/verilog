/*
    Counters
*/
`include "consts.v"
`include "flip_flop.v"

/*
    N-bit Up-Down counter with sync reset, enable bit, pre-load value

f="counter"; m="counter_behavioral"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter_behavioral #(parameter n = 3) (
    input clk,
    input res_n,
    input en,
    input count_up,
    input load,
    input [n-1:0] set,
    output reg [n-1:0] count
);
    always @(posedge clk) begin
        if (!res_n)
            count <= 0;
        else if (load)
            count <= set;
        else if (en)
            #`T_DELAY_FF count <= count + (count_up ? 1 : -1);
    end
endmodule


/*
TFF async N bit counter

This counter is sensitive to delays,
since the output of each TFF is connected to the clock of the next TFF.
So each next FF clock has additional delay !
So the minimum clock high phase time should be: num of bits (FFs) * FF delay.

f="counter"; m="counter_tff_async"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter_tff_async #(parameter n = 3, parameter count_up = 1) (
    input clk,
    input res_n,
    input en,
    output wire [n-1:0] count
);
    wire [n-1:0] ff_clk;
    generate
        genvar i;
        assign ff_clk[0] = clk;
        ff_t ff_0(.clk(ff_clk[0]), .res_n(res_n), .T(en), .Q(count[0]));
        for (i = 1; i < n; i = i + 1) begin
            assign ff_clk[i] = count_up ? ~count[i-1] : count[i-1];
            ff_t ff_i(.clk(ff_clk[i]), .res_n(res_n), .T(en), .Q(count[i]));
        end
    endgenerate
endmodule


/*
TFF sync N bit UP counter

f="counter"; m="counter_tff_sync"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter_tff_sync #(parameter n = 3) (
    input clk,
    input res_n,
    input en,
    input count_up,
    output wire [n-1:0] count
);
    wire [n-1:0] en_and;
    generate
        genvar i;
        assign en_and[0] = en;
        ff_t ff_0(.clk(clk), .res_n(res_n), .T(en), .Q(count[0]));
        for (i = 1; i < n; i = i + 1) begin
            assign en_and[i] = en_and[i-1] & (count_up ? count[i-1] : ~count[i-1]);
            ff_t ff_i(.clk(clk), .res_n(res_n), .T(en_and[i]), .Q(count[i]));
        end
    endgenerate
endmodule


/*
JKFF sync N bit Up-Down counter

f="counter"; m="counter_jkff"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter_jkff #(parameter n = 3) (
    input clk,
    input res_n,
    input en,
    input count_up,
    output wire [n-1:0] count
);
    wire J, K;
    wire [n-1:0] j, k, d;

    // Clear: J=0, K=1; hold: J=0, K=0; Clear has higher priority:
    assign J = en & res_n;
    assign K = en | ~res_n;

    // Combinational circuit with flip flops synced by same clock
    // each JK input is a product of two previous outputs (or values determined in previous circuit)
    generate
        genvar i;
        for (i = 0; i < n; i = i + 1) begin
            if (i == 0)
                assign d[i] = en;
            else
                assign d[i] = d[i-1] & (count_up ? count[i-1] : ~count[i-1]);
            assign j[i] = J != K ? J : d[i];
            assign k[i] = J != K ? K : d[i];
            ff_jk ff ( .clk(clk), .J(j[i]), .K(k[i]), .Q(count[i]) );
        end
    endgenerate
endmodule
