/*
    MUX, DEMUX, ENCODER, DECODER gates
*/

`define SYNTH         // uncomment for yosys - error parsing tri0 types
//`define GATEFLOW      // uncomment to use gate flow logic
//`define BEHAVIORAL      // uncomment to use behavioral flow logic


module mux_Nto1 #(parameter N = 16) (
    input [N-1:0] W,
    input [$clog2(N):0] SEL,
    output wire Y
);
    // synth produces a shiftx gate
    assign Y = W[SEL];
endmodule


module not_cmos (
    output wire Y,
    input din
);
    supply1 vcc;
    supply0 gnd;

    `ifdef SYNTH
        wire out;
    `else
        tri0 out;
    `endif
    //pmos p1(p_out, d_in, ctrl);
    //nmos n1(n_out, d_in, ctrl);
    pmos p1(out, vcc, din);
    nmos n1(gnd, out, din);
    assign Y = out;
endmodule


module pmos_mux (
    input W0,
    input W1,
    input SEL,
    output wire Y
);
    wire ns;

    `ifdef SYNTH
        wire out;
    `else
        tri0 out;
    `endif
    //pmos p1(p_out, d_in, ctrl);
    //nmos n1(n_out, d_in, ctrl);
    not_cmos n1(ns, SEL);
    pmos p1(out, W0, SEL);
    pmos p2(out, W1, ns);
    assign Y= out;
endmodule


module cmos_mux (
    input W0,
    input W1,
    input SEL,
    output wire Y
);
    wire ns;

    `ifdef SYNTH
        wire out;
    `else
        tri0 out;
    `endif

    not n1(ns, SEL);
    //cmos p1(out, d_in, n_ctrl, p_ctrl);
    cmos c0(out, W0, ns, SEL);
    cmos c1(out, W1, SEL, ns);
    assign Y = out;
endmodule


/*
    MUX 2 to 1

f="mux"; m="mux_2to1";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module mux_2to1 (
    input  W0,
    input  W1,
    input  SEL,
    output wire Y
);
    `ifdef GATEFLOW
        wire not_sel, and1, and2;

        not (not_sel, SEL);
        and (and1, W0, not_sel);
        and (and2, W1, SEL);
        or (Y, and1, and2);
    `else
        // synth produces a single mux
        assign Y = (SEL) ? W1 : W0;
    `endif
endmodule


/*
MUX 4 to 1

f="mux"; m="mux_4to1";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce -keepdc; simplemap; muxcover -mux4=100; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module mux_4to1(
    input [3:0] W,
    input [1:0] SEL,
    output wire Y
);
    `ifdef GATEFLOW
        wire y1, y2;

        mux_2to1 m1 ( .W0(W[0]), .W1(W[1]), .SEL(SEL[0]), .Y(y1) );
        mux_2to1 m2 ( .W0(W[2]), .W1(W[3]), .SEL(SEL[0]), .Y(y2) );
        mux_2to1 m3 ( .W0(y1), .W1(y2), .SEL(SEL[1]), .Y(Y) );
    `else
        // synth produces a single mux
        assign Y = SEL[1] ? (SEL[0] ? W[3] : W[2]) : (SEL[0] ? W[1] : W[0]);
    `endif
endmodule



/*
MUX 16 to 1

f="mux"; m="mux_16to1";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; wreduce -keepdc; simplemap; muxcover -mux4=100; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module mux_16to1(
    input [15:0] W,
    input [3:0] SEL,
    output wire Y
);
    `ifdef GATEFLOW
        wire y1, y2, y3, y4;

        mux_4to1 m1 ( .W(W[3:0]), .SEL(SEL[1:0]), .Y(y1) );
        mux_4to1 m2 ( .W(W[7:4]), .SEL(SEL[1:0]), .Y(y2) );
        mux_4to1 m3 ( .W(W[11:8]), .SEL(SEL[1:0]), .Y(y3) );
        mux_4to1 m4 ( .W(W[15:12]), .SEL(SEL[1:0]), .Y(y4) );
        mux_4to1 m5 ( .W({y4, y3, y2, y1}), .SEL(SEL[3:2]), .Y(Y) );
    `elsif BEHAVIORAL
        // synth has too much gates
        reg out;
        assign Y = out;
        always @(*) begin
            case (SEL)
                'h00: out = W[0];
                'h01: out = W[1];
                'h02: out = W[2];
                'h03: out = W[3];
                'h04: out = W[4];
                'h05: out = W[5];
                'h06: out = W[6];
                'h07: out = W[7];
                'h08: out = W[8];
                'h09: out = W[9];
                'h0A: out = W[10];
                'h0B: out = W[11];
                'h0C: out = W[12];
                'h0D: out = W[13];
                'h0E: out = W[14];
                'h0F: out = W[15];
                default: out = 0;
            endcase 
        end
    `else
        // synth produces a shiftx gate
        mux_Nto1 m1 ( .W(W), .SEL(SEL), .Y(Y) );
    `endif
endmodule


/*
DECODER 2 to 4. Can be used as a DEMUX using en = din

f="mux"; m="decoder2to4";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module decoder2to4 (
    input en,
    input [1:0] w,
    output wire [3:0] y
);
    `ifdef BEHAVIORAL
        // synth produces XORs and Mux
        reg [3:0] out;
        assign y = out;
        always @ (*) begin
            if (!en) begin
                out = 0;
            end else begin
                case (w)
                    2'b00: out = 4'b0001;
                    2'b01: out = 4'b0010;
                    2'b10: out = 4'b0100;
                    2'b11: out = 4'b1000;
                    default: out = 0;
                endcase
            end
        end
    `elsif GATEFLOW
        // synth is 2 NOTs and 8 ANDs
        wire nw0, nw1, y0, y1, y2, y3;

        not n1 (nw0, w[0]);
        not n2 (nw1, w[1]);

        and a1 (y0, nw0, nw1);
        and a2 (y1, nw1, w[0]);
        and a3 (y2, w[1], nw0);
        and a4 (y3, w[1], w[0]);

        and a5 (y[0], en, y0);
        and a6 (y[1], en, y1);
        and a7 (y[2], en, y2);
        and a8 (y[3], en, y3);
    `else
        // synth produces 2 NOT and 6 AND gates
        assign y[0] = en & ~w[1] & ~w[0];
        assign y[1] = en & ~w[1] & w[0];
        assign y[2] = en & w[1] & ~w[0];
        assign y[3] = en & w[1] & w[0];
    `endif
endmodule


/*
DECODER 4 to 16. Can be used as a DEMUX using en = din

f="mux"; m="decoder4to16";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module decoder4to16 (
    input en,
    input [3:0] w,
    output reg [15:0] y
);
    reg [3:0] out;
    // 2 lsb's decoders enabled accordinng to 2 msb's
    decoder2to4 dec1 ( .w(w[3:2]) , .en(en), .y(out) );
    decoder2to4 dec2 ( .w(w[1:0]) , .en(out[0]), .y(y[3:0]) );
    decoder2to4 dec3 ( .w(w[1:0]) , .en(out[1]), .y(y[7:4]) );
    decoder2to4 dec4 ( .w(w[1:0]) , .en(out[2]), .y(y[11:8]) );
    decoder2to4 dec5 ( .w(w[1:0]) , .en(out[3]), .y(y[15:12]) );
endmodule


/*
PRIORITY ENCODER 8 to 3

f="mux"; m="priority_enc_8to3";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m}_${m} ${m}; show ${m}"
*/
module priority_enc_8to3 (
    input [7:0] in,
    output wire [2:0] out,
    output wire valid
);
    `ifdef BEHAVIORAL
        // synth produces too much gates
        reg [2:0] p;
        assign out = p;
        assign valid = in != 0;
        
        always @(*) begin
            casex (in)
                8'b00000001: p = 3'b000;
                8'b0000001x: p = 3'b001;
                8'b000001xx: p = 3'b010;
                8'b00001xxx: p = 3'b011;
                8'b0001xxxx: p = 3'b100;
                8'b001xxxxx: p = 3'b101;
                8'b01xxxxxx: p = 3'b110;
                8'b1xxxxxxx: p = 3'b111;
                default: p = 3'b000;
            endcase
        end
    `else
        // intermediate states
        wire i1, i2, i3, i4, i5, i6, i7;

        assign i7 = in[7];
        assign i6 = ~in[7] & in[6];
        assign i5 = ~in[7] & ~in[6] & in[5];
        assign i4 = ~in[7] & ~in[6] & ~in[5] & in[4];
        assign i3 = ~in[7] & ~in[6] & ~in[5] & ~in[4] & in[3];
        assign i2 = ~in[7] & ~in[6] & ~in[5] & ~in[4] & ~in[3] & in[2];
        assign i1 = ~in[7] & ~in[6] & ~in[5] & ~in[4] & ~in[3] & ~in[2] & in[1];

        assign out[0] = i1 | i3 | i5 | i7;
        assign out[1] = i2 | i3 | i6 | i7;
        assign out[2] = i4 | i5 | i6 | i7;
        assign valid = in != 0;
    `endif
endmodule
