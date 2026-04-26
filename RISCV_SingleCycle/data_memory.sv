/*
m="data_memory"; yosys -p "read_verilog -sv ${m}.sv; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
import risc_pkg::*;


module data_memory #(
    parameter DEPTH      = 2**4, // Memory depth
    parameter DATA_WIDTH = 32,   // Memory data word width
    parameter ADDR_WIDTH = 32,   // Memory address width
    parameter SYNC_READ  = 0,    // 0 is async read (without rclk)
    parameter ENDIANESS  = 0     // 0 is Little endian
) (
    input logic clk,
    input logic res,
    input logic req,
    input logic wen,
    input logic ren,
    input logic zero_ex,
    input op_enum_dmem_size blsize,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data
);    
    logic [DATA_WIDTH-1:0] temp_rd;
    logic sign;

    memory #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ENDIANESS(ENDIANESS),
        .MEM_FILE("")
    ) mem_block (
        .rclk(clk),
        .wclk(clk),
        .res(res),
        .ren(ren),
        .wen(wen),
        .req(req),
        .addr(addr),
        .blsize(blsize),
        .wr_data(wr_data),
        .rd_data(temp_rd)
    );

    // Sign extension
    always_comb begin: get_sign_bit
        if (zero_ex)
            sign = 1'b0;
        else begin
            case (blsize)
                OP_DMEM_BYTE: sign = temp_rd[7];
                OP_DMEM_HALF: sign = temp_rd[15];
                OP_DMEM_TRPL: sign = temp_rd[23];
                OP_DMEM_WORD: sign = temp_rd[31];
                //OP_DMEM_DUBL: sign = DATA_WIDTH > 32 ? temp_rd[63] : temp_rd[31];
                default: sign = temp_rd[DATA_WIDTH-1]; // default and OP_DMEM_QUAD
            endcase
        end 
    end

    always_comb begin: sign_extend
        case (blsize)
            OP_DMEM_BYTE: rd_data = {{(DATA_WIDTH -8){sign}}, temp_rd[7:0]};
            OP_DMEM_HALF: rd_data = {{(DATA_WIDTH-16){sign}}, temp_rd[15:0]};
            OP_DMEM_TRPL: rd_data = {{(DATA_WIDTH-24){sign}}, temp_rd[23:0]};
            /*
            OP_DMEM_WORD: begin
                if (DATA_WIDTH == 32)
                    rd_data = temp_rd;
                else
                    rd_data = {{(DATA_WIDTH-32){sign}}, temp_rd[31:0]};
            end
            OP_DMEM_DUBL: begin
                if (DATA_WIDTH != 128)
                    rd_data = temp_rd;
                else
                    rd_data = {{(DATA_WIDTH-64){sign}}, temp_rd[63:0]};
            end
            */
            default: rd_data = temp_rd;
        endcase
    end
endmodule
