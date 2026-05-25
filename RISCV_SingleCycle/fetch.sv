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
    logic is_32b;
    logic req;

    // TODO: dont need 32 bits for Y
    adder #(32) pc_adder (.Nadd_sub(1'b0), .X(imem_addr), .Y({{29{1'b0}}, incr_pc}), .sum(next_pc_alu));

    // halt on cmd 0, but allow cmd zero to be the first one
    assign req = imem_addr == INST_BASE_ADDRESS | (imem_req & |imem_data[6:0]);

    // incr_pc should depend on imem_req, if imem_req becomes 1 then we can set pc to next_pc
    assign incr_pc = {imem_req & is_32b, imem_req & ~is_32b, 1'b0};    // 100 or 010 or 000
    assign next_pc = pc_mux ? pc_jump : next_pc_alu;
    assign is_32b  = IALIGN > 16 ? ~|imem_data[6:0] || &imem_data[1:0] : 0;

    always_ff @(posedge clk or posedge res) begin
        if (res)
            imem_req <= 0;
        else if (req)
            imem_req <= 1;
    end

    // PC register
    always_ff @(posedge clk or posedge res) begin
        if (res)
            imem_addr <= INST_BASE_ADDRESS;
        else if (imem_req)
            imem_addr <= next_pc;
    end
endmodule
