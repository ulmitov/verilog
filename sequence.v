/*
    4 bit sequence detector with async reset and overlapping
*/

`timescale 1ns / 1ns

/*
    m="sequence_detector"
    yosys -p "read_verilog sequence.v; hierarchy -check -top ${m}; proc; blackbox return_states; opt -nodffe -nosdff; clean; opt_share; opt_muxtree; clean; fsm_detect -ignore-self-reset; fsm; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m}; show"
    yosys -p "read_verilog sequence.v; hierarchy -check -top ${m}; proc; blackbox return_states; opt -nodffe -nosdff; clean; opt_share; opt_muxtree; clean; fsm_detect -ignore-self-reset; fsm -nomap; fsm_export -o ${m}.kiss2;"
    python3 kiss2dot.py ${m}_fsm.kiss2 > ${m}_fsm.dot; xdot ${m}_fsm.dot
*/
module sequence_detector #(parameter OVERLAP = 1) (
    input clk,
    input res_n,
    input [3:0] seq,
    input din,
    output reg dout
);
    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;
    wire [1:0] r1, r2, r3, c3;
    (* fsm_encoding = "auto" *) reg [1:0] state;
    reg [1:0] next_state;
    
    if (OVERLAP)
        // define overlapping states per current sequence
        return_states rs (.seq(seq), .r1(r1), .r2(r2), .r3(r3), .s3(c3));
    else begin
        // if din matches the first seq bit then we should move to S1
        assign r1 = din === seq[3] ? S1 : S0;
        assign r2 = din === seq[3] ? S1 : S0;
        assign r3 = din === seq[3] ? S1 : S0;
        assign c3 = S0;
    end

    // State update. Reset is async. Dout is sync.
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            state <= S0;
            dout <= 0;
        end else begin
            state <= next_state;
            dout <= (state == S3 && din === seq[0]) ? 1'b1 : 1'b0;
        end
    end

    always @(*) begin
        case (state)
            S0:
                next_state = din === seq[3] ? S1 : S0;
            S1:
                next_state = din === seq[2] ? S2 : r1;
            S2:
                next_state = din === seq[1] ? S3 : r2;
            S3:
                next_state = din === seq[0] ? c3 : r3;
            default:
                next_state = S0;
        endcase
    end
endmodule


/*
    Define return states for overlapping patterns

    m="return_states"
    yosys -p "read_verilog sequence.v; hierarchy -check -top ${m}; proc; opt -nodffe -nosdff; clean; opt_share; opt_muxtree; techmap; clean; stat; write_verilog -noattr synth/sequence_detector_${m}_synth.v; show -format svg -prefix synth/sequence_detector_${m}; show"
*/
module return_states(
    input [3:0] seq,
    output wire [1:0] r1,
    output wire [1:0] r2,
    output wire [1:0] r3,
    output wire [1:0] s3
);
    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    assign r1 = (seq[3] ^~ seq[2]) ? S0 : S1;
    assign r2 = (seq[3] ^~ seq[2] && seq[2] ^ seq[1]) ? S2 : (seq[3] ^ seq[1] ? S1 : S0);
    assign r3 = (seq[3] ^~ seq[2] && seq[2] ^~ seq[1] && seq[1] ^ seq[0]) ? S3 : ((seq[3] ^~ seq[1] && seq[1] ^~ seq[0] && seq[3] ^ seq[2]) ? S2 : (seq[3] ^ seq[0] ? S1 : S0));
    assign s3 = (seq[3] ^~ seq[2] && seq[2] ^~ seq[1] && seq[1] ^~ seq[0]) ? S3 : ((seq[3] ^~ seq[1] && seq[2] ^~ seq[0]) ? S2 : (seq[3] ^ seq[0] ? S0 : S1));
endmodule


/*
    Basic 1010 detector with overlapping

    f="sequence"; m="sequence_detector_1010"
    yosys -p "read_verilog sequence.v; hierarchy -check -top ${m}; proc; opt -nodffe -nosdff; clean; opt_share; opt_muxtree; clean; fsm_detect -ignore-self-reset; fsm -nomap; fsm_export -o ${m}_fsm.kiss2; stat; write_verilog -noattr synth/${m}_synth.v; show -format svg -prefix synth/${m}; show"
    python3 kiss2dot.py ${m}_fsm.kiss2 > ${m}_fsm.dot; xdot ${m}_fsm.dot

    add "simplemap;" after fsm step (without nomap) to see 2 DFFs
*/
module sequence_detector_1010 (
    input clk,
    input res_n,
    input din,
    output wire out
);
    parameter pass = 4'b1010;
    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;
    (* fsm_encoding = "binary" *) reg [1:0] state;
    reg [1:0] next_state;

    // State update. Reset is async.
    always @(posedge clk or negedge res_n) begin
        if (!res_n)
            state <= S0;
        else
            state <= next_state;
    end

    assign out = (state == S3 && din ^~ pass[0]) ? 1'b1 : 1'b0;

    always @(*) begin
        case (state)
            S0:
                next_state = din ^~ pass[3] ? S1 : S0;
            S1:
                next_state = din ^~ pass[2] ? S2 : S1;
            S2:
                next_state = din ^~ pass[1] ? S3 : S0;
            S3:
                next_state = din ^~ pass[0] ? S2 : S1;
            default:
                next_state = S0;
        endcase
    end
endmodule


/*
    optimized FSM's for 1010
*/
module sequence_detector_1010_mealy(
    input clk,
    input res_n,
    input din,
    output reg dout
);
    reg s2, s1;

    // DFF update. Reset is async.
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            s1 <= 0;
            s2 <= 0;
            dout <= 0;
        end else begin
            s1 <= din;
            s2 <= (din & s2 & ~s1) | (~din & s1);
            dout <= ~din & s2 & s1;
        end
    end
endmodule


module sequence_detector_1010_moore(
    input clk,
    input res_n,
    input din,
    output wire dout
);
    reg s2, s1, s3;

    assign dout = s3;

    // DFF update. Reset is async.
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            s1 <= 0;
            s2 <= 0;
            s3 <= 0;
        end else begin
            s1 <= din;
            s3 <= ~din & s1 & s2;
            s2 <= (~din & s1) | (din & ~s1 & (s2 | s3));
        end
    end
endmodule
