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
    logic [DIV_WIDTH-1:0] counter;
    logic [DIV_WIDTH-1:0] next_count;
    logic cycle_full;
    logic switch_clk;
    logic half_cycle;
    logic baud_out;
    logic dlm_set;
    logic dll_set;

    generate
        if (`UART_DATA_WIDTH < DIV_WIDTH) begin
            assign dlm_set      = |div[DIV_WIDTH-1:`UART_DATA_WIDTH];
            assign dll_set      = |div[`UART_DATA_WIDTH-1:1];
        end else begin
            assign dlm_set      = 1'b1;
            assign dll_set      = |div[DIV_WIDTH-1:1];
        end
    endgenerate

    assign cycle_full   = counter == div;
    assign half_cycle   = counter == {1'b0, div[DIV_WIDTH-1:1]};// counter == div >> 1
    assign switch_clk   = cycle_full | half_cycle;              // odd dividers will not get exact 50% phase
    assign next_count   = counter + 1;

    always_comb begin
        casez({dlm_set, dll_set, div[0]})
            3'b11?:   clk_out = baud_out;
            3'b01?:   clk_out = baud_out;
            3'b10?:   clk_out = baud_out;
            3'b001:   clk_out = clk_in;
            default:  clk_out = 1'b1;
        endcase
    end

    always_ff @(posedge clk_in or posedge res) begin
        if (res | cycle_full)
            counter <= 1;
        else
            counter <= next_count;
    end
    always_ff @(posedge clk_in or posedge res) begin
        if (res)
            baud_out <= 1'b1;
        else if (switch_clk)
            baud_out <= #`T_DELAY_FF ~baud_out;
    end
endmodule
