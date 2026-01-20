
`timescale 1ns / 100ps


module shift_tb;
    localparam n = 8;
    reg [n-1:0] din, exp_r, exp_l;
    wire [n-1:0] out_r, out_l;
    reg [$clog2(n):0] shifts;
    integer i, val;

    shift_right #(n) uut_r (.din(din), .shift_n(shifts), .shifted(out_r));
    shift_left  #(n) uut_l (.din(din), .shift_n(shifts), .shifted(out_l));

    task check_values;
    input [n-1:0] in;
    input [$clog2(n)-1:0] sh;
    begin
        din = in;
        shifts = sh;
        exp_r = din >> sh;
        exp_l = din << sh;
        #1 if (out_r != exp_r)
            $display("ERROR R: %4d: din=%8b, shifts=%0d (%3b), out_r=%8b, exp=%8b", $time, din, shifts, shifts, out_r, exp_r);
        if (out_l != exp_l)
            $display("ERROR L: %4d: din=%8b, shifts=%0d (%3b), out_l=%8b, exp=%8b", $time, din, shifts, shifts, out_l, exp_l);
    end
    endtask

    initial begin
        $dumpfile("vcd/shift.vcd");
        $dumpvars();
        //$monitor("%4d: din=%8b, shifts=%0d (%3b), out_r=%8b, out_l=%8b", $time, din, shifts, shifts, out_r, out_l);
        for (val = 1; val < 2**n -1; val = val + 1) begin
            for (i = 0; i < n; i = i + 1)
                check_values(val, i);
        end
        $finish;
    end
endmodule
