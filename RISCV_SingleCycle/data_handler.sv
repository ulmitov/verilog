import risc_pkg::*;


/* 
For Stype align rs2_data with block size
*/
module data_handler #(parameter XLEN = RISCV_XLEN) (
    input op_enum_dmem_size block_size,
    input logic [XLEN-1:0] data_in,
    output logic [XLEN-1:0] data_out
);
    generate
        if (XLEN == 8) assign data_out = data_in;
        if (XLEN == 16) begin
            always_comb begin
                case(block_size)
                    OP_DMEM_BYTE: data_out = {{(XLEN-08){1'b0}}, data_in[7:0]};
                    default: data_out = data_in;
                endcase
            end
        end
        if (XLEN >= 32) begin
            always_comb begin
                case(block_size)
                    OP_DMEM_BYTE: data_out = {{(XLEN-08){1'b0}}, data_in[7:0]};
                    OP_DMEM_HALF: data_out = {{(XLEN-16){1'b0}}, data_in[15:0]};
                    OP_DMEM_TRPL: data_out = {{(XLEN-24){1'b0}}, data_in[23:0]};
                    OP_DMEM_WORD: data_out = {{(XLEN-32){1'b0}}, data_in[31:0]};
                    //OP_DMEM_DUBL: data_out = {data_in[63:0]};
                    default: data_out = data_in;
                endcase
            end
        end
    endgenerate
endmodule
