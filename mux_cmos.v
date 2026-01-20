`define SYNTH           // uncomment for yosys - error parsing tri0 types


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
    //nmos (strong1, strong0) (delay_r, delay_f, delay_o ) gg (n_out, d_in, ctrl);
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
