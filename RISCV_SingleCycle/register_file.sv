/*
Register File unit

Asm regs:
x0 is known as zero
X1 is return address
x2 is stack pointer
x3 global pointer
x4 thread pointer
x5 temp return addr
x10 through x17 are a0 through a7
x5,x6,x7,x28-x31 are t0-t6
x8,x9,x18-x27 are s0-s11
*/
module register_file #(parameter XLEN = 32) (
    input logic clk,
    input logic res_n,
    input logic rf_wr_en,
    input logic [4:0] rd_addr,
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [XLEN-1:0] wr_data,

    output logic [XLEN-1:0] rs1_data,
    output logic [XLEN-1:0] rs2_data
);
    logic [XLEN-1:0] reg_mem [0:31];
    integer i;

    assign rs1_data = reg_mem[rs1_addr];
    assign rs2_data = reg_mem[rs2_addr];

    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n) begin
            for (i = 0; i < XLEN; i = i + 1)
                reg_mem[i] <= {XLEN{1'b0}};
        end else if (rf_wr_en && rd_addr != 5'b0)
            reg_mem[rd_addr] <= wr_data;
    end
endmodule
