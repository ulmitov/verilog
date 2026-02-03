/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */
`include "consts.v"


/* posedge D flip flop with async neg reset and simple synchronizer - N bit register */
module ff_d #(parameter N = 1, parameter SYNCHRONIZER = 0) (
    input clk,
    input res_n,
    input en,
    input [N-1:0] din,
    output reg [N-1:0] Q
);
    reg pipe_0;
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            if (SYNCHRONIZER) pipe_0 <= 0;
            Q <= 0;
        end else if (en) begin
            if (SYNCHRONIZER) begin
                pipe_0 <= #`T_DELAY_FF din;
                Q <= #`T_DELAY_FF pipe_0;
            end else
                Q <= #`T_DELAY_FF din;
        end
    end
endmodule


/* posedge T Flip Flop with async neg reset */
module ff_t (
    input clk,
    input res_n,
    input T,
    output reg Q
);
    always @(posedge clk or negedge res_n) begin
        if (!res_n)
            Q <= 0;
        else if (T)
            #`T_DELAY_FF Q <= ~Q;
        else
            #`T_DELAY_FF Q <= Q;
    end
endmodule


module ff_jk (
    input clk,
    input J,
    input K,
    output reg Q
);
    // synced clear instead of reset
    always @(posedge clk) begin
        case ({J, K})
            2'b00: #`T_DELAY_FF Q <= Q;
            2'b01: Q <= 1'b0;
            2'b10: Q <= 1'b1;
            2'b11: #`T_DELAY_FF Q <= ~Q;
            default: Q <= 1'bX;
        endcase
    end
endmodule
