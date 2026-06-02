import risc_pkg::*;


module decode (
    input logic [IALIGN-1:0] instruction,
    
    output logic [6:0] opcode,
    output logic [4:0] rd_addr,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic [31:0] immediate,
    output logic r_type,
    output logic i_type,
    output logic s_type,
    output logic b_type,
    output logic u_type,
    output logic j_type,
    output logic is_op32,
    output logic is_32bit,
    output logic c_type,    // CSR commands
    output logic y_type,    // System commands
    output logic illegal
);
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;
    logic [1:0] opcode16;
    logic reg_ok;
    logic func3_ok;
    logic illegal_op;
    logic illegal_funct3;

    generate
        if (IALIGN < 32)
            assign is_32bit = 1'b0;
        else
            assign is_32bit  = ~|instruction[6:0] | &opcode16;
    endgenerate

    assign illegal  = illegal_op | illegal_funct3;
    assign reg_ok   = |rd_addr | |rs1_addr;
    assign func3_ok = |funct3;
    assign opcode16 = instruction[1:0];
    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct7   = instruction[31:25];
    assign funct3   = is_32bit ? instruction[14:12] : instruction[15:13];

    assign imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
    assign imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign imm_s = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    assign imm_u = {instruction[31:12], 12'b0}; // same as imm << 12

    assign immediate =  s_type ? imm_s :
                        i_type ? imm_i :
                        b_type ? imm_b :
                        u_type ? imm_u :
                        j_type ? imm_j : {RISCV_XLEN{1'b0}};

    always_comb begin
        s_type = 1'b0;
        i_type = 1'b0;
        b_type = 1'b0;
        r_type = 1'b0;
        u_type = 1'b0;
        j_type = 1'b0;
        c_type = 1'b0;
        y_type = 1'b0;
        is_op32 = 1'b0;
        illegal_op = 1'b0;
        illegal_funct3 = 1'b0;

        case(opcode)
            OPCODE_RTYPE_32: begin
                r_type = 1'b1;
                is_op32 = 1'b1;
            end
            OPCODE_R_TYPE:          r_type = 1'b1;
            OPCODE_S_TYPE:          s_type = 1'b1;
            OPCODE_B_TYPE: begin
                b_type = 1'b1;
                if (funct3 === 3'b010 | funct3 === 3'b011) illegal_funct3 = 1'b1;
            end
            OPCODE_U_TYPE_JAL:      j_type = 1'b1;
            OPCODE_U_TYPE_LUI,
            OPCODE_U_TYPE_AUIPC:    u_type = 1'b1;
            OPCODE_I_TYPE_FL:       illegal_op = 1'b1;  // (Not implemented) this is i_type = 1'b1;
            OPCODE_I_TYPE_ALU,
            OPCODE_I_TYPE_LOAD,
            OPCODE_I_TYPE_JALR:     i_type = 1'b1;
            OPCODE_ITYPE_IMM_32: begin
                i_type = 1'b1;
                is_op32 = 1'b1;
            end
            OPCODE_SYSTEM: begin
                if (funct3 === 'b100)
                    // r_type = 1'b1;   // (Not implemented) Hypervisor Virtual-Machine Load and Store Instructions
                    illegal_funct3 = 1'b1;
                else begin
                    i_type = 1'b1;
                    if (func3_ok & reg_ok)
                        `ifdef ZICSR
                            c_type = 1'b1;
                        `else
                            illegal_funct3 = 1'b1;
                        `endif
                    else if (~func3_ok & ~reg_ok)
                        y_type = 1'b1;    
                    else
                        illegal_funct3 = 1'b1;  // but not for HFENCE
                end
            end
            default: illegal_op = 1'b1;
        endcase
    end
endmodule
