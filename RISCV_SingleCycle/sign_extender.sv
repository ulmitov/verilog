import risc_pkg::*;


module sign_extender #(parameter DATA_WIDTH = 32) (
    input logic zero_ex,
    input op_enum_dmem_size blsize,
    input logic [DATA_WIDTH-1:0] data_in,
    output logic [DATA_WIDTH-1:0] data_out
);    
    logic sign;

    always_comb begin: get_sign_bit
        case (blsize)
            OP_DMEM_BYTE: sign = data_in[7];
            OP_DMEM_HALF: sign = data_in[15];
            OP_DMEM_TRPL: sign = data_in[23];
            OP_DMEM_WORD: sign = data_in[31];
            //OP_DMEM_DUBL: sign = DATA_WIDTH > 32 ? data_in[63] : data_in[31];
            default: sign = data_in[DATA_WIDTH-1]; // default and OP_DMEM_QUAD
        endcase
    end

    always_comb begin: sign_extend
        if (zero_ex)
            data_out = data_in;
        else begin
            case (blsize)
                OP_DMEM_BYTE: data_out = {{(DATA_WIDTH -8){sign}}, data_in[7:0]};
                OP_DMEM_HALF: data_out = {{(DATA_WIDTH-16){sign}}, data_in[15:0]};
                OP_DMEM_TRPL: data_out = {{(DATA_WIDTH-24){sign}}, data_in[23:0]};
                /*
                OP_DMEM_WORD: begin
                    if (DATA_WIDTH == 32)
                        data_out = data_in;
                    else
                        data_out = {{(DATA_WIDTH-32){sign}}, data_in[31:0]};
                end
                OP_DMEM_DUBL: begin
                    if (DATA_WIDTH != 128)
                        data_out = data_in;
                    else
                        data_out = {{(DATA_WIDTH-64){sign}}, data_in[63:0]};
                end
                */
                default: data_out = data_in;
            endcase
        end
    end
endmodule
