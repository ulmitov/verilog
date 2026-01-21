/* 
    Shift combibational circuits
    Using MUXes to do the shift operations in one clock cycle
*/
/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */


/*
Shift right and left optimized.
For shift left using shift right with reversed bits for din and out.

m="shift"; 
yosys -p "read_verilog shift.v mux.v; hierarchy -check -top $m; proc; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module shift #(parameter n = 4) (
    input right_en, // 0- sh left, 1- sh right
    input sign,
    input [n-1:0] din,
    input [$clog2(n):0] shift_n,
    output wire [n-1:0] out
);
    wire sign_in;
    wire [n-1:0] data, shifted;
    genvar k;

    shift_right #(n) shr (.sign(sign_in), .din(data), .shift_n(shift_n), .shifted(shifted));

    assign sign_in = right_en & sign;

    generate
        // TODO: here also can use mux_2to1. This will add two more T_DELAY_PD levels for calc time.
        for (k = 0; k < n; k = k + 1) begin
            assign data[k] = right_en ? din[k] : din[n-k-1];
            assign out[k] =  right_en ? shifted[k] : shifted[n-k-1];
        end
    endgenerate
endmodule


/*
m="shift_right"; 
yosys -p "read_verilog shift.v mux.v; hierarchy -check -top $m; proc; clean; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module shift_right #(parameter n = 4) (
    input sign,
    input [n-1:0] din,
    input [$clog2(n):0] shift_n,
    output wire [n-1:0] shifted
);
    localparam shifts_num = $clog2(n);
    wire [n-1:0] stages [0:shifts_num];
    wire msb;
    genvar s, b;

    generate
        // stage 0 we input the bits from din
        assign stages[0] = din;
        assign msb = sign & din[n-1];
        // stage muxes. each stage shifts by 2**s
        for (s = 0; s < shifts_num; s = s + 1) begin
            // bit muxes
            for (b = 0; b < n; b = b + 1) begin
                if (b >= n - 2**s)
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(msb), .SEL(shift_n[s]), .Y(stages[s+1][b]));
                else
                    mux_2to1 mux_stage_bit (.W0(stages[s][b]), .W1(stages[s][b+2**s]), .SEL(shift_n[s]), .Y(stages[s+1][b]));
            end
        end
        // if number of shifts bigger than size of din, then output 0
        assign shifted = shift_n[shifts_num] ? {n{msb}} : stages[shifts_num];
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
