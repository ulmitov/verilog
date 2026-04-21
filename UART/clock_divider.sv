/*
    Clock divider (Baud Rate Generation)

If divider value is unknown then clk out is a constant 1

f="clock_divider.sv"; m="clock_divider";
yosys -p "read_verilog -sv ${f}; hierarchy -check -top $m; proc; opt; clean; show -format svg -prefix ${m} ${m}; show ${m}"
*/
module clock_divider #(parameter DIV_WIDTH = 16) (
    input res,
    input clk_in,
    input [DIV_WIDTH-1:0] div,
    output logic clk_out
);
    logic [DIV_WIDTH-1:0] counter, next_count;
    logic cycle_init, cycle_full, switch_clk, half_cycle;

    assign cycle_init   = counter == 1;
    assign cycle_full   = counter == div;
    assign half_cycle   = counter == {1'b0, div[DIV_WIDTH-1:1]};// counter == div >> 1
    assign switch_clk   = cycle_full | half_cycle;              // odd dividers will not get exact 50% phase
    assign next_count   = counter + 1;

    always_ff @(posedge clk_in or posedge res) begin
        if (res)
            counter <= 1;
        else if (cycle_full)
            counter <= 1;
        else
            counter <= next_count;
    end
    always_ff @(posedge clk_in or posedge res) begin
        if (res)
            clk_out <= 1'b1;
        else if (switch_clk)
            clk_out <= ~clk_out;
        else if ($isunknown(switch_clk))
            clk_out <= 1'b1;
    end
endmodule
