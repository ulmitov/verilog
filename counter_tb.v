`timescale 1ns / 1ns;


module counter_tb();
  parameter n = 4;
  parameter T_CYC = 20;

  reg res_n, enable, up_down, load;
  reg clk = 1'b1;
  reg [n-1:0] set;
  wire [n-1:0] count;

  integer i, expected;

  counter #(n) dut (.clk(clk), .res_n(res_n), .up_down(up_down), .enable(enable), .load(load), .set(set), .count(count));

  always #10 clk = ~clk;

  always
    #T_CYC if (expected !== count) $display("%0d: count=%0d not as expected %0d", $time, count, expected);

  initial begin
    $dumpfile("results/counter_tb.vcd");
    $dumpvars(0, counter_tb);
    $monitor("%0d: en=%0d ud=%0d, set=%0b, count=%0d", $time, enable, up_down, set, count);

    res_n = 0;
    load = 0;
    expected = 0;
    #T_CYC;
    #T_CYC res_n = 1;
    
    for (i = 0; i < 2; i += 1) #T_CYC;

    enable = 1;
    up_down = 1;
    for (i = 0; i < 2**n - 1; i += 1) begin
      expected += 1;
      #T_CYC;
    end

    up_down = 0;
    for (i = 0; i < 2**n - 1; i += 1) begin
       expected -= 1;
       #T_CYC;
    end
    
    load = 1;
    set = 2**n - 1;
    expected = set;
    #T_CYC set = 0;
    load = 0;
    for (i = 0; i < 2**n - 1; i += 1) begin
       expected -= 1;
       #T_CYC;
    end
    $finish;
  end
endmodule
