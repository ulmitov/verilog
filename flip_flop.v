/* posedge D flip flop with sync reset - n bit register */
module ff_d (
    input clk,
    input res_n,
    input din,
    output reg Q
);
    specify
        $setup(d, q, 25);
    endspecify
    always @(posedge clk or negedge res_n) begin
        if (!res_n)
            Q <= 0;
        else
            Q <= din;
    end
endmodule


/* T Flip Flop with async neg reset */
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
            Q <= ~Q;
        else
            Q <= Q;
    end
endmodule


/* JK Flip Flop */
module ff_jk (
    input clk,
    input J,
    input K,
    output reg Q
);
    // synced clear instead of reset
    always @(posedge clk) begin
        case ({J, K})
            2'b00: Q <= Q;
            2'b01: Q <= 1'b0;
            2'b10: Q <= 1'b1;
            2'b11: Q <= ~Q;
            default: Q <= 1'bX;
        endcase
    end
endmodule
