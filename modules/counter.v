/*
    Counters
*/
/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */

`include "consts.vh"
`include "flip_flop.v"

/*
    N-bit Up-Down counter with sync reset, enable bit, pre-load value

f="counter"; m="counter"
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module counter #(parameter n = 4) (
    input clk,
    input res_n,
    input en,
    input count_up,
    input load_en,
    input [n-1:0] load,
    output wire [n-1:0] count
);
    `ifdef GATE_FLOW_OFF
        reg [n-1:0] C;
        assign count = C;
        always @(posedge clk) begin
            if (!res_n)
                C <= 0;
            else if (load_en)
                C <= load;
            else if (en)
                C <= #`T_DELAY_FF C + (count_up ? 1 : -1);
        end
    `else
        wire [n-1:0] en_xor;
        wire [n-1:0] din_and;
        generate
            genvar i;
            for (i = 0; i < n; i = i + 1) begin: dff
                if (i == 0) begin
                    assign din_and[0] = en;
                    assign en_xor[0] = load_en ? load[0] : en ^ count[0];
                end else begin
                    assign din_and[i] = din_and[i-1] & (count_up ^~ count[i-1]);
                    assign en_xor[i] = load_en ? load[i] : din_and[i] ^ (count[i]);
                end
                ff_d dff_i(.clk(clk), .res_n(res_n), .en(en), .din(en_xor[i]), .Q(count[i]));
            end
        endgenerate
    `endif
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
        for (i = 0; i < n; i = i + 1) begin: tff
            if (i == 0)
                assign ff_clk[0] = clk;
            else
                assign ff_clk[i] = count_up ^ count[i-1];
            ff_t tff_i(.clk(ff_clk[i]), .res_n(res_n), .T(en), .Q(count[i]));
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
    
    wire [n-1:0] en_and;;
    generate
        genvar i;
        for (i = 0; i < n; i = i + 1) begin: tff
            if (i == 0)
                assign en_and[0] = en;
            else
                assign en_and[i] = en_and[i-1] & (count_up ^~ count[i-1]);
            ff_t tff_i(.clk(clk), .res_n(res_n), .T(en_and[i]), .Q(count[i]));
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
    wire [n-1:0] j, k;
    wire [n-1:0] d;
    wire J, K;

    // Clear: J=0, K=1; hold: J=0, K=0; Clear has higher priority:
    assign J = en & res_n;
    assign K = en | ~res_n;

    // Combinational circuit with flip flops synced by same clock
    // each JK input is a product of two previous outputs (or values determined in previous circuit)
    generate
        genvar i;
        for (i = 0; i < n; i = i + 1) begin: jkff
            if (i == 0)
                assign d[i] = en;
            else
                assign d[i] = d[i-1] & (count_up ^~ count[i-1]);
            assign j[i] = J != K ? J : d[i];
            assign k[i] = J != K ? K : d[i];
            ff_jk jkff_i ( .clk(clk), .J(j[i]), .K(k[i]), .Q(count[i]) );
        end
    endgenerate
endmodule
