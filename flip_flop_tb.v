`timescale 1ns / 1ns

module ff_jk_tb;
    reg j, k, clk;
    wire Q;

    ff_jk uut (.Q(Q), .clk(clk), .J(j), .K(k));

    always #5 clk = ~clk;

    initial begin
        $dumpfile("vcd/ff_jk_tb.vcd");
        $dumpvars(0, ff_jk_tb);
        clk = 1;
        $monitor("%d j=%b, k=%b, Q=%b", $time, j, k, Q);
        $display("*** TC: JK Flip Flop ***");
        k = 1;
        #10 j = 0;
        #10 j = 0; k = 0;
        #10 j = 0; k = 1;
        #10 j = 1; k = 0;
        #10 j = 1; k = 1;
        #20 $finish;
    end
endmodule
