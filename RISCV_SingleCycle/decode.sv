import risc_pkg::*;


module decode (
    input logic [31:0] instruction,
    
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
    output logic j_type
);
    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;

    assign opcode   = instruction[6:0];
    assign rd_addr  = instruction[11:7];
    assign funct3   = instruction[14:12];
    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign funct7   = instruction[31:25];

    assign imm_s = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    assign imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign imm_u = {instruction[31:12], 12'b0}; // same as imm << 12
    assign imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    assign immediate =  s_type ? imm_s :
                        i_type ? imm_i :
                        b_type ? imm_b :
                        u_type ? imm_u :
                        j_type ? imm_j : 32'b0;

    always_comb begin
        s_type = 1'b0;
        i_type = 1'b0;
        b_type = 1'b0;
        r_type = 1'b0;
        u_type = 1'b0;
        j_type = 1'b0;

        case(opcode)
            OPCODE_R_TYPE:          r_type = 1'b1;
            OPCODE_S_TYPE:          s_type = 1'b1;
            OPCODE_B_TYPE:          b_type = 1'b1;
            OPCODE_J_TYPE:          j_type = 1'b1;
            OPCODE_U_TYPE_LUI,
            OPCODE_U_TYPE_AUIPC:    u_type = 1'b1;
            OPCODE_I_TYPE_ALU,
            OPCODE_I_TYPE_LOAD,
            OPCODE_I_TYPE_JALR:     i_type = 1'b1;
        endcase
        $strobe("%0d: OPCODE=%7b funct3=%0b, , rs1_addr=%0h, rs2_addr=%0h, IMM=%0h", $time, opcode, funct3, rs1_addr, rs2_addr, immediate);
    end
endmodule
