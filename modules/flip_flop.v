/* verilator lint_off DECLFILENAME */
/* verilator lint_off MULTITOP */
/* verilator lint_off GENUNNAMED */
`include "consts.vh"


/* posedge D flip flop with async neg reset - N bit register */
module ff_d #(parameter N = 1) (
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
            Q <= #`T_DELAY_FF din;
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
    Simple N bit synchronizer of 2-4 stages with edges detection
    Assuming din is 1-1.5 phases longer than clk, it can be used for clock crossing the din signal
*/
module synchroniser #(parameter DATA_WIDTH = 1, parameter STAGES = 3, parameter RES_VAL = 1) (
    input clk,
    input res,
    input [DATA_WIDTH-1:0] din,
    output wire [DATA_WIDTH-1:0] dout,
    output reg [DATA_WIDTH-1:0] edges   // din edge detector
);
    localparam INIT_VAL = RES_VAL ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
    reg [DATA_WIDTH-1:0] q0;
    reg [DATA_WIDTH-1:0] q1;

    // Stage 1
    always @(posedge clk or posedge res) begin
        if (res)
            q0 <= INIT_VAL;
        else
            q0 <= din;
    end

    // Stage 2
    always @(posedge clk or posedge res) begin
        if (res)
            q1 <= INIT_VAL;
        else
            q1 <= q0;
    end

    if (STAGES > 2) begin
        reg [DATA_WIDTH-1:0] q2;
        always @(posedge clk or posedge res) begin
            if (res)
                q2 <= INIT_VAL;
            else
                q2 <= q1;
        end

        if (STAGES == 4) begin
            reg [DATA_WIDTH-1:0] q3;
            always @(posedge clk or posedge res) begin
                if (res)
                    q3 <= INIT_VAL;
                else
                    q3 <= q2;
            end
            assign dout = q3;
        end else begin
            assign dout = q2;
        end
    end else begin
        assign dout = q1;
    end

    // Edge detector
    always @(posedge clk or posedge res) begin
        if (res)
            edges <= 0;
        else
            edges <= edges ^ dout;
    end
endmodule
