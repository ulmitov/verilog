// assuming Little endian
module instruction_memory #(
    parameter MEM_FILE = "machine_code.mem",
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8
) (
    input logic imem_req,           // read enable
    input logic [31:0] imem_addr,   // byte address
    output logic [31:0] imem_data   // output instruction
);
    logic [DATA_WIDTH-1:0] mem [0:2**ADDR_WIDTH-1];

    // Init ROM data
    initial begin
        $readmemh(MEM_FILE, mem);
    end

    always_comb begin
        if (imem_req) begin
            imem_data = {         // each instruction is 4 bytes
                mem[imem_addr],
                mem[imem_addr + 1],
                mem[imem_addr + 2],
                mem[imem_addr + 3]
            };
        end else begin
            imem_data = 32'b0;
        end
    end
endmodule
