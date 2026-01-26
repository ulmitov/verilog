
module fetch (
    input logic clk,
    input logic res_n,
    input logic [31:0] pc,
    input logic [31:0] imem_data,

    output logic imem_req,
    output logic [31:0] imem_addr,
    output logic [31:0] instruction
);
    logic req_reg;
    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n)
            req_reg <= 0;
        else
            req_reg <= 1;
    end
    assign imem_addr = pc;
    assign imem_req = req_reg;
    assign instruction = imem_data;
endmodule
