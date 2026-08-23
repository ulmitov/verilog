`include "consts.vh"
/*
Clock divider (Baud Rate Generation)

f="clock_divider.sv"; m="clock_divider";
yosys -p "read_verilog -sv ${f}; hierarchy -check -top $m; proc; opt; clean; show -format svg -prefix ${m} ${m}; show ${m}"
*/
module clock_divider #(parameter DIV_WIDTH = 16) (
    input logic res,
    input logic clk_in,
    input logic polarity,   // initial value
    input logic phase,      // one phase delay
    input logic [DIV_WIDTH-1:0] div,
    output logic clk_out
);
    logic [DIV_WIDTH-1:0] counter;
    logic [DIV_WIDTH-1:0] next_count;
    logic cycle_full;
    logic switch_clk;
    logic half_cycle;
    logic dlm_set;
    logic dll_set;
    logic fixed_phase;
    logic fixed_pol;
    logic baud_out = polarity === 1'b0 ? 1'b0 : 1'b1; // default output, same as fixed_pol mux

    generate
        if (DIV_WIDTH >= 8) begin
            assign dlm_set      = |div[DIV_WIDTH-1:8];
            assign dll_set      = |div[7:1];
        end else begin
            assign dlm_set      = 1'b0;
            assign dll_set      = |div[DIV_WIDTH-1:1];
        end
    endgenerate

    assign cycle_full   = counter == div;
    assign half_cycle   = counter == {1'b0, div[DIV_WIDTH-1:1]};// counter == div >> 1
    assign switch_clk   = cycle_full | half_cycle;              // odd dividers will not get exact 50% phase
    assign next_count   = counter + 1;

    always_comb begin
        case (phase)
            1'b1:       fixed_phase = 1'b1;
            default:    fixed_phase = 1'b0;
        endcase
    end

    always_comb begin
        case (polarity)
            1'b0:       fixed_pol = 1'b0;
            default:    fixed_pol = 1'b1;
        endcase
    end

    always_comb begin
        casez ({dlm_set, dll_set, div[0]})
            3'b11?:   clk_out = baud_out;
            3'b01?:   clk_out = baud_out;
            3'b10?:   clk_out = baud_out;   // div > 1
            3'b001:   clk_out = clk_in;     // div = 1
            default:  clk_out = fixed_pol;  // div unset
        endcase
    end

    // When either of the divisor latches is loaded,
    // baud counter is also loaded to prevent long counts.
    // if phase is 1 then start count from 0
    always_ff @(posedge clk_in or posedge res) begin
        if (res)
            counter <= {{(DIV_WIDTH-1){1'b0}}, ~fixed_phase};
        else if (cycle_full)
            counter <= 1;
        else
            counter <= next_count;
    end

    always_ff @(posedge clk_in or posedge res) begin
        if (res)
            baud_out <= fixed_pol;
        else if (switch_clk)
            baud_out <= #`T_DELAY_FF ~baud_out;
    end
endmodule
