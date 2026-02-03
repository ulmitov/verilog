`include "consts.v"
`timescale 1ns / 100ps

`define T_CLK 5
`define T_CYC (2*`T_CLK)


module shift_reg_tb;
    localparam N = 4;

    reg din = 1'b0;
    reg en = 1'b0;
    reg clk = 1'b0;
    reg load_en = 1'b0;
    reg res_n = 1'b1;
    reg [N-1:0] load = {N{1'b0}};
    wire dout;

    always #`T_CLK clk = ~clk;
    
    shift_reg #(.N(N)) dut (.clk(clk), .res_n(res_n), .en(en), .din(din), .load_en(load_en), .load(load), .dout(dout));
    
    initial begin
        $dumpfile("vcd/shift_reg_tb.vcd");
        $dumpvars;
        $monitor("%0d: din=%0b, dout=%0b", $time, din, dout);
        #`T_CYC res_n = 0;
        #`T_CYC res_n = 1;
        en = 1'b1;
        din = 1'b1;
        #(`T_CYC) din = 1'b0;
        #(N*`T_CYC);
        din = 1'b1;
        #(2*`T_CYC) din = 1'b0;
        #(N*`T_CYC);
        #(`T_CYC) din = 1'b1;
        #(`T_CYC) din = 1'b0;
        #(`T_CYC) din = 1'b1;
        #(`T_CYC) din = 1'b0;
        #(N*`T_CYC);
        #(`T_CYC) $finish;
    end
endmodule
