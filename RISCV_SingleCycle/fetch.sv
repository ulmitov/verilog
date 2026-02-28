module fetch (
    input logic clk,
    input logic res_n,
    input logic pc_mux,
    input logic [31:0] pc_jump,
    input logic [31:0] imem_data,

    output logic imem_req,
    output logic [31:0] imem_addr,
    output logic [31:0] next_pc_alu
);
    logic [31:0] next_pc;   // the real next pc that should be taken according to ALU or branch control
    logic req;

    adder_full_n #(32) pc_adder (.X(imem_addr), .Y(32'h4), .Cin(1'b0), .sum(next_pc_alu), .carry());

    assign req = imem_data != NOP_CMD || imem_data[6:0] == OPCODE_SYSTEM;
    assign next_pc = pc_mux ? pc_jump : next_pc_alu;

    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n)
            imem_addr <= RESET_PC;
        else if (req)
            imem_addr <= next_pc;
    end

    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n | ~req)
            imem_req <= 0;
        else
            imem_req <= 1;
    end
endmodule
