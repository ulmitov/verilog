`include "consts.v"


/* posedge D flip flop with async neg reset - N bit register */
module ff_d #(parameter N = 4) (
    input clk,
    input res_n,
    input en,
    input [N-1:0] din,
    output reg [N-1:0] Q
);
    always @(posedge clk or negedge res_n) begin
        if (!res_n)
            Q <= 0;
        else if (en)
            #`T_FF_DELAY Q <= din;
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
            #`T_FF_DELAY Q <= ~Q;
        else
            #`T_FF_DELAY Q <= Q;
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
            2'b00: #`T_FF_DELAY Q <= Q;
            2'b01: Q <= 1'b0;
            2'b10: Q <= 1'b1;
            2'b11: #`T_FF_DELAY Q <= ~Q;
            default: Q <= 1'bX;
        endcase
    end
endmodule

