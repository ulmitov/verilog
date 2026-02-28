`include "consts.v"
import risc_pkg::*;


module riscv #(
    parameter XLEN = RISCV_XLEN,
    parameter MEM_DEPTH = 128,          // Data memory depth
    parameter MEM_FILE = "memcode.mem"  // Machine code to load on init
) (
    input logic clk,
    input logic res_n
);
    logic [31:0] pc, pc_jump, next_pc_alu;
    logic [31:0] instruction, immediate;
    logic [31:0] dmem_addr;
    logic [XLEN-1:0] dmem_wr_data, dmem_rd_data;
    logic [XLEN-1:0] alu_a, alu_b, alu_res;
    logic [XLEN-1:0] rs1_data, rs2_data, rf_wr_data;
    logic imem_req, pc_mux;
    logic branch_taken, rf_wr_en;
    logic pc_sel, op1_sel, op2_sel;
    logic dmem_zero_ex, dmem_req, dmem_wr;
    logic r_type, i_type, s_type, b_type, u_type, j_type;
    logic [4:0] rd_addr, rs1_addr, rs2_addr;
    logic [6:0] opcode;
    logic [6:0] funct7;
    logic [2:0] funct3;
    op_enum_alu alu_op;
    op_enum_dmem_size dmem_size;
    op_enum_wr_data_sel rf_wr_data_sel;


    memory #(
        .DEPTH(2**8),       // 2**8/4 = 64 instructions (for non DEBUG set to 32)
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .MEM_FILE(MEM_FILE),
        .ENDIANESS(1)       // readmemh is big endian
    ) instruction_mem (
        .rclk(), .wclk(), .res(),  .wen(), .wr_data(),
        .req(1'b1),
        .zero_ex(1'b1),
        .mem_size(OP_DMEM_WORD),
        .ren(imem_req),
        .addr(pc),
        .rd_data(instruction)
    );


    fetch fetch_stage (
        .clk(clk),
        .res_n(res_n),
        .pc_mux(pc_mux),
        .pc_jump(pc_jump),
        .imem_data(instruction),
        .imem_req(imem_req),
        .imem_addr(pc),
        .next_pc_alu(next_pc_alu)
    );


    decode decode_stage(
        .instruction(instruction),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .immediate(immediate),
        .r_type(r_type),
        .i_type(i_type),
        .s_type(s_type),
        .b_type(b_type),
        .u_type(u_type),
        .j_type(j_type)
    );


    register_file #(XLEN) reg_file (
        .clk(clk),
        .res_n(res_n),
        .rf_wr_en(rf_wr_en),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .wr_data(rf_wr_data)
    );


    branch_control branch_ctrl (
        .b_type(b_type),
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_taken(branch_taken)
    );


    memory #(
        .DATA_WIDTH(XLEN),
        .DEPTH(MEM_DEPTH),
        .ADDR_WIDTH(32),
        .MEM_FILE(""),
        .ENDIANESS(0)
    ) data_mem (
        .rclk(),
        .wclk(clk),
        .res(~res_n),
        .ren(1'b1),
        .wen(dmem_wr),
        .req(dmem_req),
        .addr(dmem_addr),
        .mem_size(dmem_size),
        .zero_ex(dmem_zero_ex),
        .wr_data(dmem_wr_data),
        .rd_data(dmem_rd_data)
    );


    alu #(XLEN) alu_stage (
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
        .dmem_size(dmem_size),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_zero_ex(dmem_zero_ex),
        .rf_wr_en(rf_wr_en),
        .rf_wr_data_sel(rf_wr_data_sel)
    );


    `ifdef DEBUG
        // DEBUG only: set x when no need for data
        assign dmem_addr = dmem_req ? alu_res[31:0] : {32{1'bX}};
        assign dmem_wr_data = dmem_req ? rs2_data : {XLEN{1'bX}};
    `else
        assign dmem_addr = alu_res;
        assign dmem_wr_data = rs2_data;
    `endif

    assign alu_a = op1_sel ? pc : rs1_data;         // 1- pc, 0- rs1
    assign alu_b = op2_sel ? immediate : rs2_data;  // 1- imm, 0- rs2
    assign pc_mux = branch_taken | pc_sel;          // pc_sel: 1-alu_res(jump), 0-next_pc
    assign pc_jump = {alu_res[XLEN-1:1], 1'b0};

    always_comb begin
        case (rf_wr_data_sel)
            OP_RF_SEL_ALU: rf_wr_data = alu_res;
            OP_RF_SEL_MEM: rf_wr_data = dmem_rd_data;
            OP_RF_SEL_IMM: rf_wr_data = immediate;
            OP_RF_SEL_PC:  rf_wr_data = next_pc_alu;
        endcase
    end
endmodule
