`include "consts.vh"
import risc_pkg::*;


module riscv_core #(
    parameter XLEN = RISCV_XLEN
) (
    input logic clk,
    input logic res_n,
    input logic [IALIGN-1:0] instruction,
    input logic [XLEN-1:0] rs1_data,
    input logic [XLEN-1:0] rs2_data,
    input logic [XLEN-1:0] dmem_rd_data,

    output logic imem_req,
    output logic rf_wr_en,
    output logic [31:0] pc,
    output logic [4:0] rd_addr, rs1_addr, rs2_addr,
    output logic [31:0] dmem_addr,
    output logic [XLEN-1:0] rf_wr_data,
    output logic [XLEN-1:0] dmem_wr_data,
    output logic dmem_zero_ex,
    output logic dmem_req,
    output logic dmem_wr,
    output op_enum_dmem_size dmem_size
);
    logic [31:0] pc_jump, next_pc_alu;
    logic [31:0] immediate;
    logic [XLEN-1:0] alu_a, alu_b, alu_res;
    logic [XLEN-1:0] signed_rd_data;
    logic pc_mux;
    logic branch_taken;
    logic pc_sel, alua_sel, alub_sel;
    logic r_type, i_type, s_type, b_type, u_type, j_type;
    logic [6:0] opcode;
    logic [6:0] funct7;
    logic [2:0] funct3;
    op_enum_alu alu_op;
    op_enum_wr_data_sel rf_wr_data_sel;


    fetch fetch_block (
        .clk(clk),
        .res(~res_n),
        .pc_mux(pc_mux),
        .pc_jump(pc_jump),
        .imem_data(instruction),
        .imem_req(imem_req),
        .imem_addr(pc),
        .next_pc_alu(next_pc_alu)
    );


    decode decode_block(
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


    branch_control branch_block (
        .b_type(b_type),
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch_taken(branch_taken)
    );


    alu #(XLEN) alu_block (
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b),
        .alu_res(alu_res)
    );


    control ctrl_block (
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
        .alua_sel(alua_sel),
        .alub_sel(alub_sel),
        .dmem_size(dmem_size),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_zero_ex(dmem_zero_ex),
        .rf_wr_en(rf_wr_en),
        .rf_wr_data_sel(rf_wr_data_sel)
    );


    data_handler #(.XLEN(XLEN)) dh_block (
        .block_size(dmem_size),
        .data_in(rs2_data),
        .data_out(dmem_wr_data)
    );


    sign_extender #(.DATA_WIDTH(XLEN)) sign_block (
        .blsize(dmem_size),
        .zero_ex(dmem_zero_ex),
        .data_in(dmem_rd_data),
        // outputs:
        .data_out(signed_rd_data)
    );


    `ifdef DEBUG_RUN
        // DEBUG only: set x when no need for data
        assign dmem_addr = dmem_req ? alu_res : 'bX;
    `else
        assign dmem_addr = alu_res;
    `endif

    assign alu_a    = alua_sel ? pc : rs1_data;         // 0- rs1_data, 1- pc
    assign alu_b    = alub_sel ? immediate : rs2_data;  // 0- rs2_data, 1- imm
    assign pc_mux   = branch_taken | pc_sel;            // pc_sel: 0- next_pc, 1- alu_res(jump)
    assign pc_jump  = {alu_res[XLEN-1:1], 1'b0};

    always_comb begin
        case (rf_wr_data_sel)
            OP_RF_SEL_ALU: rf_wr_data = alu_res;
            OP_RF_SEL_MEM: rf_wr_data = signed_rd_data;
            OP_RF_SEL_IMM: rf_wr_data = immediate;
            OP_RF_SEL_PC:  rf_wr_data = next_pc_alu;
        endcase
    end
endmodule
