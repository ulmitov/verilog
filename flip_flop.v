/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */
`include "consts.v"


/* posedge D flip flop with async neg reset - N bit register */
module ff_d #(parameter N = 1) (
    input clk,
    input res_n,
    input en,
    input [N-1:0] din,
    output reg [N-1:0] Q
);
    reg pipe_0;
    always @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            Q <= 0;
        end else if (en) begin
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


/*
    Simple single synchronizer of two stage shift register FF's
    with an edge detector
    Assuming din is 1-1.5 phases longer than clk, it can be used for clock crossing the din signal
*/
module synchroniser #(parameter n = 1) (
    input clk,
    input res,
    input [n-1:0] din,
    output wire [n-1:0] q,
    output wire [n-1:0] edges   // din edge detector
);
    reg [n-1:0] q0, q1;
    assign q = q1;
    always @(posedge clk) begin
        if (res) begin
            q0 <= 0;
            q1 <= 0;
            edges <= 0;
        end else begin
            q0 <= din;
            q1 <= q0;
            edges <= edges ^ q1;
        end
    end
endmodule
