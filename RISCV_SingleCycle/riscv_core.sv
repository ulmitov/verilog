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
    input logic irq_sw_pending,
    input logic irq_ex_pending,
    input logic irq_timer_pending,

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
    logic [31:0] next_pc_default;
    logic [31:0] next_pc;
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
    logic y_type;
    logic c_type;
    logic illegal_dec;
    logic rf_en;
    logic pc_jump;
    logic rd_ok;
    logic rs1_ok;
    logic non_zero_cmd;

    // ZICSR:
    logic irq_start;
    logic irq_stop;
    logic [XLEN-1:0] mtvec_offset;
    logic [XLEN-1:0] csr_data_out;


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
        .c_type(c_type),
    // outputs:
        .alu_op(alu_op),
        .pc_sel(pc_sel),
        .alua_sel(alua_sel),
        .alub_sel(alub_sel),
        .dmem_size(dmem_size),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_zero_ex(dmem_zero_ex),
        .rf_wr_en(rf_en),
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
        .is_op32(is_op32),
        .y_type(y_type),
        .c_type(c_type),
        .illegal(illegal_dec),
        .rd_ok(rd_ok),
        .rs1_ok(rs1_ok)
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


    `ifndef ZICSR
        assign irq_start = 1'b0;
        assign irq_stop = 1'b0;
    `else
        csr #(XLEN) csr_block (
            .clk(clk),
            .res(~res_n),
            .c_type(c_type),
            .y_type(y_type),
            .rd_ok(rd_ok),
            .rs_ok(rs1_ok),
            .imem_req(imem_req),
            .instruction(instruction),
            .sys_imm(immediate[11:0]),
            .pc(pc),
            .csr_din(alu_res),
            .irq_illegal(illegal_dec & non_zero_cmd),
            .irq_ex_pending(irq_ex_pending),
            .irq_sw_pending(irq_sw_pending),
            .irq_timer_pending(irq_timer_pending),
        // outputs:
            .irq_start(irq_start),
            .irq_stop(irq_stop),
            .offset(mtvec_offset),
            .csr_out(csr_data_out)
        );
    `endif


    assign dmem_addr = alu_res;
    assign rf_wr_en = rf_en & rd_ok & ~irq_start;

    // ALU_A select mux: 0- rs1_data, 1- pc
    always_comb begin
    `ifdef ZICSR
        if (irq_stop)           // take mepc
            alu_a = csr_data_out;
        else
        if (irq_start)          // take mtvec
            alu_a = {csr_data_out[XLEN-1:2], 2'b00};
        else
        if (c_type) begin
            case (funct3)
                OP_FUNCT3_CSRRW:    alu_a = rs1_data;
                OP_FUNCT3_CSRRS:    alu_a = rs1_data;
                OP_FUNCT3_CSRRC:    alu_a = ~rs1_data;
                OP_FUNCT3_CSRRWI:   alu_a = {{(XLEN-5){1'b0}}, rs1_addr};
                OP_FUNCT3_CSRRSI:   alu_a = {{(XLEN-5){1'b0}}, rs1_addr};   // set
                OP_FUNCT3_CSRRCI:   alu_a = {{(XLEN-5){1'b1}}, ~rs1_addr};  // clear
            endcase
        end else
    `endif
        if (alua_sel)
            alu_a = pc;
        else
            alu_a = rs1_data;
    end

    // ALU_B select mux: 0- rs2_data, 1- imm
    always_comb begin
    `ifdef ZICSR
        if (irq_stop)
            alu_b = 'h4;                // jump to mepc + 4
        else if (irq_start)
            alu_b = mtvec_offset;
        else if (c_type & funct3[1])    // CSRRS/C
            alu_b = csr_data_out;
        else if (c_type & ~funct3[1])   // CSRRW
            alu_b = {XLEN{1'b0}};
        else
    `endif
        if (alub_sel)
            alu_b = {{(XLEN-32){immediate[31]}}, immediate};
        else
            alu_b = rs2_data;
    end


    // OP-32: result is trancated to 32 bits and sign extended
    generate
        if (XLEN > 32)
            assign alu_res_signed = is_op32 ? {{32{alu_res[31]}}, alu_res[31:0]} : alu_res;
        else
            assign alu_res_signed = alu_res;
    endgenerate


    always_comb begin
        if (~c_type) begin
            case (rf_wr_data_sel)
                OP_RF_SEL_ALU: rf_wr_data = alu_res_signed;
                OP_RF_SEL_MEM: rf_wr_data = signed_rd_data;
                OP_RF_SEL_IMM: rf_wr_data = {{(XLEN-32){immediate[31]}}, immediate};
                OP_RF_SEL_PC:  rf_wr_data = {{(XLEN-32){1'b0}}, next_pc_default};
            endcase
        end
        `ifdef ZICSR
            else rf_wr_data = csr_data_out;
        `endif
    end


    // --- FETCH LOGIC ---
    // halt on cmd zero, but allow cmd zero to be the first one
    assign non_zero_cmd = |instruction;     // maybe only |opcode will be enough?
    assign inst_req = (pc === INST_BASE_ADDRESS | non_zero_cmd);

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
        else if (imem_req === 1'b1)
            pc <= next_pc;
    end

    // PC select
    assign pc_jump = branch_taken | pc_sel | irq_start | irq_stop;

    always_comb begin
        if (pc_jump)
            next_pc = {alu_res[31:1], 1'b0};    // for now Inst ROM is always 32 bits
        else
            next_pc = next_pc_default;
    end

    // TODO: dont need 32 bits for Y
    logic [31:0] pc_alu_b;
    assign pc_alu_b = {{29{1'b0}}, imem_req & is_32b_instr, imem_req & ~is_32b_instr, {1'b0}};  // 100 or 010 or 000
    adder #(32) pc_adder (
        .Nadd_sub(1'b0),
        .X(pc),
        .Y(pc_alu_b),  
        .sum(next_pc_default)
    );
endmodule
