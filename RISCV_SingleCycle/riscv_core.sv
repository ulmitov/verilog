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
    output logic [4:0] rd_addr,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    output logic [31:0] dmem_addr,
    output logic [XLEN-1:0] rf_wr_data,
    output logic [XLEN-1:0] dmem_wr_data,
    output logic dmem_zero_ex,
    output logic dmem_req,
    output logic dmem_wr,
    output op_enum_dmem_size dmem_size
);
    logic [31:0] next_pc_alu;
    logic [31:0] next_pc;   // the real next pc that should be taken according to ALU or branch control
    logic [31:0] immediate;
    logic [XLEN-1:0] alu_a;
    logic [XLEN-1:0] alu_b;
    logic [XLEN-1:0] alu_res;
    logic [XLEN-1:0] alu_res_signed;
    logic [XLEN-1:0] signed_rd_data;
    logic pc_sel;
    logic r_type;
    logic i_type;
    logic s_type;
    logic b_type;
    logic u_type;
    logic j_type;
    logic alua_sel;
    logic alub_sel;
    logic branch_taken;
    logic is_32b_instr;
    logic [6:0] opcode;
    logic [6:0] funct7;
    logic [2:0] funct3;
    op_enum_alu alu_op;
    op_enum_wr_data_sel rf_wr_data_sel;
    logic inst_req;
    logic is_op32;
    logic op_sys;


    alu #(XLEN) alu_block (
        .alu_op(alu_op),
        .alu_a(alu_a),
        .alu_b(alu_b),
    // outputs:
        .alu_res(alu_res)
    );


    branch_control #(XLEN) branch_block (
        .b_type(b_type),
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
    // outputs:
        .branch_taken(branch_taken)
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
        .op_sys(op_sys),
    // outputs:
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


    decode decode_block(
        .instruction(instruction),
    // outputs:
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
        .j_type(j_type),
        .is_32bit(is_32b_instr),
        .op_sys(op_sys),
        .is_op32(is_op32)
    );


    data_handler #(XLEN) dh_block (
        .block_size(dmem_size),
        .data_in(rs2_data),
    // outputs:
        .data_out(dmem_wr_data)
    );


    sign_extender #(XLEN) sign_block (
        .blsize(dmem_size),
        .zero_ex(dmem_zero_ex),
        .data_in(dmem_rd_data),
    // outputs:
        .data_out(signed_rd_data)
    );


    // ALU_A select mux: 0- rs1_data, 1- pc
    always_comb begin
        if (alua_sel)
            alu_a = pc;
        else
            alu_a = rs1_data;
    end

    // ALU_B select mux: 0- rs2_data, 1- imm
    always_comb begin
        if (~alub_sel)
            alu_b = rs2_data;
        else
            alu_b = {{(XLEN-32){immediate[31]}}, immediate};
    end


    // PC select order prioritized
    always_comb begin
        if (branch_taken | pc_sel)         // pc_sel: 0- next_pc, 1- alu_res(jump)
            next_pc = {alu_res[31:1], 1'b0};    // for now Inst ROM is always 32 bits, so taking alu_res from bit 31
        else
            next_pc = next_pc_alu;
    end


    // --- PC LOGIC ---

    // halt on cmd 0, but allow cmd zero to be the first one
    assign inst_req = pc == INST_BASE_ADDRESS | |opcode;
    assign dmem_addr = alu_res;

    always_ff @(posedge clk or negedge res_n) begin
        if (~res_n)
            imem_req <= 0;
        else
            imem_req <= inst_req;
    end


    // PC register
    always_ff @(posedge clk or negedge res_n) begin
        if (~res_n)
            pc <= INST_BASE_ADDRESS;
        else if (imem_req)
            pc <= next_pc;
    end


    // OP-32: result is trancated to 32 bits and sign extended
    generate
        if (XLEN > 32)
            assign alu_res_signed = is_op32 ? {{32{alu_res[31]}}, alu_res[31:0]} : alu_res;
        else
            assign alu_res_signed = alu_res;
    endgenerate


    always_comb begin
        case (rf_wr_data_sel)
            OP_RF_SEL_ALU: rf_wr_data = alu_res_signed;
            OP_RF_SEL_MEM: rf_wr_data = signed_rd_data;
            OP_RF_SEL_IMM: rf_wr_data = {{(XLEN-32){immediate[31]}}, immediate};
            OP_RF_SEL_PC:  rf_wr_data = {{(XLEN-32){1'b0}}, next_pc_alu};
        endcase
    end


    // TODO: dont need 32 bits for Y
    adder #(32) pc_adder (
        .Nadd_sub(1'b0),
        .X(pc),
        .Y({{29{1'b0}}, imem_req & is_32b_instr, imem_req & ~is_32b_instr, {1'b0}}),  // 100 or 010 or 000
        .sum(next_pc_alu)
    );
endmodule
