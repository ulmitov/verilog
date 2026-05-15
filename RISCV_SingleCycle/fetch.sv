module fetch (
    input logic clk,
    input logic res,
    input logic pc_mux,
    input logic [31:0] pc_jump,
    input logic [IALIGN-1:0] imem_data,

    output logic imem_req,
    output logic [31:0] imem_addr,
    output logic [31:0] next_pc_alu
);
    logic [31:0] next_pc;   // the real next pc that should be taken according to ALU or branch control
    logic [2:0] incr_pc;
    logic is_32bit;
    logic req;

    // TODO: dont need 32 bits for Y
    adder #(32) pc_adder (.Nadd_sub(1'b0), .X(imem_addr), .Y({{29{1'b0}}, incr_pc}), .sum(next_pc_alu));

    // halt in case instruction is 0 or if got system command
    assign req = imem_req & |imem_data[6:0] & imem_data[6:0] != OPCODE_SYSTEM;
    assign is_32bit = &imem_data[1:0];

    // incr_pc should depend on req, if req becomes 1 then we can set pc to next_pc
    assign incr_pc = {req & is_32bit, req & ~is_32bit, 1'b0};    // 100 or 010 or 000
    assign next_pc = pc_mux ? pc_jump : next_pc_alu;

    always_ff @(posedge clk or posedge res) begin
        if (res)
            imem_addr <= INST_BASE_ADDRESS;
        else if (req)
            imem_addr <= next_pc;
    end

    always_ff @(posedge clk or posedge res) begin
        if (res)
            imem_req <= 0;
        else
            imem_req <= 1;
    end
endmodule
