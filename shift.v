/* 
    Shift right combibational circuits
    based on MUXes to do shift operations in one clock cycle
*/
/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */

/*
m="shift_right"; 
yosys -p "read_verilog shift.v mux.v; hierarchy -check -top $m; proc; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/

module shift_right #(parameter n = 4) (
    input [n-1:0] din,
    input [$clog2(n):0] shift_n,
    output wire [n-1:0] shifted
);
    localparam shifts_num = $clog2(n);
    wire [n-1:0] stages [0:shifts_num];
    genvar s, b;

    generate
        // stage 0 we input the bits from din
        assign stages[0] = din;
        // stage muxes. each stage shifts by 2**s
        for (s = 0; s < shifts_num; s = s + 1) begin
            // bit muxes
            for (b = 0; b < n; b = b + 1) begin
                if (b >= n - 2**s)
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(1'b0), .SEL(shift_n[s]), .Y(stages[s+1][b]));
                else
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(stages[s][b+2**s]), .SEL(shift_n[s]), .Y(stages[s+1][b]));
            end
        end
        // if number of shifts bigger than size of din, then output 0
        assign shifted = shift_n[shifts_num] ? {n{1'b0}} : stages[shifts_num];
    endgenerate
endmodule


module shift_left #(parameter n = 8) (
    input [n-1:0] din,
    input [$clog2(n):0] shift_n,
    output wire [n-1:0] shifted
);
    localparam shifts_num = $clog2(n);
    wire [n-1:0] stages [0:shifts_num];
    genvar s, b;

    generate
        // stage 0 we input the bits from din
        assign stages[0] = din;
        // stage muxes. each stage shifts by 2**s
        for (s = 0; s < shifts_num; s = s + 1) begin
            // bit muxes
            for (b = 0; b < n; b = b + 1) begin
                if (b < 2**s)
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(1'b0), .SEL(shift_n[s]), .Y(stages[s+1][b]));
                else
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(stages[s][b-2**s]), .SEL(shift_n[s]), .Y(stages[s+1][b]));
            end
        end
        // if number of shifts bigger than size of din, then output 0
        assign shifted = shift_n[shifts_num] ? {n{1'b0}} : stages[shifts_num];
    endgenerate
endmodule
