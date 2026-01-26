// assuming Little endian
import risc_pkg::*;

/*
f="data_memory"; m="data_memory";
yosys -p "read_verilog -sv ${f}.sv; hierarchy -check -top $m; proc; opt; simplemap; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
module data_memory #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8
) (
    input logic clk,
    input logic dmem_zero_ex,
    input logic dmem_req,
    input logic dmem_wr,
    input op_dmem_size dmem_size,
    input logic [31:0] dmem_addr,
    input logic [31:0] dmem_wr_data,

    output logic [31:0] dmem_rd_data
);
    logic [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];
    logic [31:0] temp_rd;
    logic zero_ex;

    // Write operation
    always_ff @(posedge clk) begin
        if (dmem_req & dmem_wr) begin
            if (dmem_size == OP_DMEM_WORD)
                {mem[dmem_addr+3], mem[dmem_addr+2], mem[dmem_addr+1], mem[dmem_addr]} <= dmem_wr_data;
            else if (dmem_size == OP_DMEM_HALF)
                {mem[dmem_addr+1], mem[dmem_addr]} <= dmem_wr_data[15:0];
            else
                mem[dmem_addr] <= dmem_wr_data[7:0];
        end
    end
    // Read operation
    assign temp_rd = {mem[dmem_addr+3], mem[dmem_addr+2], mem[dmem_addr+1], mem[dmem_addr]};

    always_comb begin
        if (dmem_req & ~dmem_wr) begin
            if (dmem_zero_ex === 1'b0) begin
                case (dmem_size)
                    OP_DMEM_BYTE: zero_ex = temp_rd[7];
                    OP_DMEM_HALF: zero_ex = temp_rd[15];
                    default: zero_ex = 1'b0;
                endcase
            end else
                zero_ex = 1'b0;
            
            case (dmem_size)
                OP_DMEM_BYTE: dmem_rd_data = {{24{zero_ex}}, temp_rd[7:0]};
                OP_DMEM_HALF: dmem_rd_data = {{16{zero_ex}}, temp_rd[15:0]};
                default: dmem_rd_data = temp_rd;
            endcase
        end else
            dmem_rd_data = 32'b0;
    end
endmodule
