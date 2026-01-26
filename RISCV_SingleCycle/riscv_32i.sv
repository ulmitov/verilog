import risc_pkg::*;


module riscv_32i #(
    parameter RESET_PC = 32'h0,
    parameter ADDR_WIDTH = 16,
    parameter DATA_WIDTH = 8,
    parameter MEM_FILE = "memcode.mem"
) (
    input logic clk,
    input logic res_n
);
    logic [31:0] pc, next_pc, next_seq_pc, pc_jump;
    logic [31:0] imem_addr, imem_data, instruction, immediate, rs1_data, rs2_data, wr_data;
    logic [31:0] dmem_rd_data, alu_a, alu_b, alu_res;
    logic r_type, i_type, s_type, b_type, u_type, j_type;
    logic branch_taken, rf_wr_en;
    logic dmem_zero_ex, dmem_req, dmem_wr;
    logic pc_sel, op1_sel, op2_sel;
    logic imem_req, pc_en, pc_mux;
    logic [4:0] rd_addr, rs1_addr, rs2_addr;
    logic [6:0] opcode;
    logic [6:0] funct7;
    logic [2:0] funct3;
    op_alu_enum alu_op;
    op_dmem_size dmem_size;
    op_wr_data_sel rf_wr_data_sel;


    instruction_memory #( .MEM_FILE(MEM_FILE), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) inst_mem (
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_data(imem_data)
    );


    fetch fetch_stage (
        .clk(clk),
        .res_n(res_n),
        .pc(pc),
        .imem_data(imem_data),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .instruction(instruction)
    );


    decode decode_stage(
        .instruction(instruction),
        .opcode(opcode),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .funct3(funct3),
        .funct7(funct7),
        .immediate(immediate),
        .r_type(r_type),
        .i_type(i_type),
        .s_type(s_type),
        .b_type(b_type),
        .u_type(u_type),
        .j_type(j_type)
    );

    register_file reg_file (
        .clk(clk),
        .res_n(res_n),
        .rf_wr_en(rf_wr_en),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .wr_data(wr_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );


    branch_control branch_ctrl (
        .b_type(b_type),
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_taken(branch_taken)
    );

    // for vcd debug - see x when no need for data
    logic [31:0] dmem_addr;
    assign dmem_addr = dmem_req ? alu_res : 32'bX;

    logic [31:0] dmem_wr_data;
    assign dmem_wr_data = dmem_req ? rs2_data : 32'bX;

    data_memory #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) data_mem (
        .clk(clk),
        .dmem_zero_ex(dmem_zero_ex),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_size(dmem_size),
        .dmem_addr(dmem_addr),
        .dmem_wr_data(dmem_wr_data),
        .dmem_rd_data(dmem_rd_data)
    );

    alu alu_stage (
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_res(alu_res)
    );

    control ctrl (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .r_type(r_type),
        .i_type(i_type),
        .s_type(s_type),
        .b_type(b_type),
        .u_type(u_type),
        .j_type(j_type),
        .alu_op(alu_op),
        .pc_sel(pc_sel),
        .op1_sel(op1_sel),
        .op2_sel(op2_sel),
        .rf_wr_data_sel(rf_wr_data_sel),
        .dmem_size(dmem_size),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_zero_ex(dmem_zero_ex),
        .rf_wr_en(rf_wr_en)
    );

    // start fetching on the next clock after reset is done
    // NOP is 00000013
    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n)
            pc_en <= 1'b0;
        else if (|opcode | ~|opcode)
            pc_en <= 1'b1;
    end

    always_ff @(posedge clk or negedge res_n) begin
        if (!res_n)
            pc = RESET_PC;
        else if (pc_en)
            pc <= next_pc;
    end

    
    adder_full_n #(32) pc_adder (.X(pc), .Y(32'h4), .Cin(1'b0), .sum(next_seq_pc), .carry());
    //assign next_seq_pc = pc + 32'h4;
    assign pc_jump = {alu_res[31:1], 1'b0};
    assign alu_a = op1_sel ? pc : rs1_data; // 1- pc, 0- rs1
    assign alu_b = op2_sel ? immediate : rs2_data; // 1- imm, 0- rs2
    assign pc_mux = branch_taken | pc_sel;   // pc_sel: 1-alu_res(jump), 0-next_pc
    assign next_pc = pc_mux ? pc_jump : next_seq_pc;


    always_comb begin
        case (rf_wr_data_sel)
            OP_RF_SEL_ALU: wr_data = alu_res;
            OP_RF_SEL_MEM: wr_data = dmem_rd_data;
            OP_RF_SEL_IMM: wr_data = immediate;
            OP_RF_SEL_PC: wr_data = next_seq_pc;
        endcase
    end
endmodule
