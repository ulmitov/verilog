/*
Sync and async Memory

In the asynchronous mode, the operation of the memory is only synchronous with respect to the clock signal WClock.
Data are read from the RAM memory space at RAddress into Q after some delay when RAddress has changed.
The behavior of the memory is unknown if you write and read at the same addr.
The output Q depends on the time relationship between the write clock and the read addr signal.

m="memory"; yosys -p "read_verilog ${m}.sv; hierarchy -check -top $m; proc; opt; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"

TODO: add logic to handle out of bound addresses, f.e. blsize=OP_DMEM_QUAD with addr=0x1f8
*/
`include "consts.vh"
import risc_pkg::*;


module memory #(
    parameter DEPTH      = 2**4,    // Memory depth
    parameter DATA_WIDTH = 32,      // Memory data word width
    parameter ADDR_WIDTH = 32,      // Memory address width
    parameter SYNC_READ  = 0,       // 0 is async read (without clk)
    parameter ENDIANESS  = 0,       // 0 is Little endian
    parameter MEM_FILE   = ""       // machine hex code file path for init
) (
    input logic wclk,
    input logic res,
    input logic req,
    input logic wen,
    input logic ren,
    input op_enum_dmem_size blsize,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data
);
    parameter MAXBL = DATA_WIDTH / 8;
    logic [7:0] MEMX [0:DEPTH-1];    // Each mem address holds 1 byte
    logic [DATA_WIDTH-1:0] reg_rd;
    logic rd_en;
    logic wr_en;

    assign wr_en = ~res & req & wen;
    assign rd_en = req & ren;


    task initmem;
        input string path;
        begin
            $display("--- MEMORY LOADING %s ---", path);
            $readmemh(path, MEMX);
        end
    endtask

    // Init memory
    if (MEM_FILE != "") begin: init_memfile
        initial initmem(MEM_FILE);
    end

    // set suitbale block size value according to requested block size and predefined DATA_WIDTH
    logic [2:0] block_size;
    always_comb begin
        case(blsize)
            OP_DMEM_QUAD: block_size = MAXBL > 8 ? 5 : 0; // 16 bytes
            OP_DMEM_DUBL: block_size = MAXBL > 4 ? 4 : 0; // 8 bytes
            OP_DMEM_WORD: block_size = MAXBL > 3 ? 3 : 0; // 4 bytes
            OP_DMEM_TRPL: block_size = MAXBL > 2 ? 2 : 0; // 3 bytes
            OP_DMEM_HALF: block_size = MAXBL > 1 ? 1 : 0; // 2 bytes
            default: block_size = 0;    // OP_DMEM_BYTE
        endcase
    end


    // WR operation: TODO: add BIG ENDIAN
    always_ff @(posedge wclk) begin
        if (wr_en) begin
            MEMX[addr] <= #`T_DELAY_FF wr_data[7:0];
        end
    end

    generate
        if (DATA_WIDTH >= 16) begin
            always_ff @(posedge wclk) begin
                if (wr_en) begin
                    if (block_size > 0) begin
                        if (!ENDIANESS)
                            MEMX[addr+1] <= #`T_DELAY_FF wr_data[15:8];
                    end
                end
            end
        end

        if (DATA_WIDTH >= 24) begin
            always_ff @(posedge wclk) begin
                if (wr_en) begin
                    if (block_size > 1) begin
                        if (!ENDIANESS)
                            MEMX[addr+2] <= #`T_DELAY_FF wr_data[23:16];
                    end
                end
            end
        end

        if (DATA_WIDTH >= 32) begin
            always_ff @(posedge wclk) begin
                if (wr_en) begin
                    if (block_size > 2) begin
                        if (!ENDIANESS)
                            MEMX[addr+3] <= #`T_DELAY_FF wr_data[31:24];
                    end
                end
            end
        end

        if (DATA_WIDTH >= 64) begin
            always_ff @(posedge wclk) begin
                if (wr_en) begin
                    if (block_size > 3) begin
                        if (!ENDIANESS)
                            {MEMX[addr+7], MEMX[addr+6], MEMX[addr+5], MEMX[addr+4]} <= #`T_DELAY_FF wr_data[63:32];
                    end
                end
            end
        end

        if (DATA_WIDTH >= 128) begin
            always_ff @(posedge wclk) begin
                if (wr_en) begin
                    if (block_size > 4) begin
                        if (!ENDIANESS) begin
                            {MEMX[addr+11], MEMX[addr+10], MEMX[addr+9], MEMX[addr+8]}  <= #`T_DELAY_FF wr_data[95:64];
                            {MEMX[addr+15], MEMX[addr+14], MEMX[addr+13], MEMX[addr+12]}<= #`T_DELAY_FF wr_data[127:96];
                        end
                    end
                end
            end
        end
    endgenerate


    // RD operation
    generate
        if (!SYNC_READ) begin: async_read
            assign rd_data = reg_rd;
        end
        else
        begin: sync_read
            always_ff @(posedge wclk) begin
                if (res)
                    rd_data <= 0;
                else if (rd_en) begin
                    rd_data <= #`T_DELAY_FF reg_rd;
                end
            end
        end
    endgenerate


    generate
        if (DATA_WIDTH >= 128) begin
            always_latch begin
                if (rd_en) begin
                    if (block_size == 5) begin
                        if (ENDIANESS) begin
                            reg_rd[127:96] = {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
                            reg_rd[95:64]  = {MEMX[addr+4], MEMX[addr+5], MEMX[addr+6], MEMX[addr+7]};
                            reg_rd[63:32]  = {MEMX[addr+8], MEMX[addr+9], MEMX[addr+10], MEMX[addr+11]};
                            reg_rd[31:0]   = {MEMX[addr+12], MEMX[addr+13], MEMX[addr+14], MEMX[addr+15]};
                        end else begin
                            reg_rd[127:96] = {MEMX[addr+15], MEMX[addr+14], MEMX[addr+13], MEMX[addr+12]};
                            reg_rd[95:64]  = {MEMX[addr+11], MEMX[addr+10], MEMX[addr+9], MEMX[addr+8]};
                            reg_rd[63:32]  = {MEMX[addr+7], MEMX[addr+6], MEMX[addr+5], MEMX[addr+4]};
                            reg_rd[31:0]   = {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
                        end
                    end
                    if (block_size == 4) reg_rd[DATA_WIDTH-1:64] = 0;
                end
            end
        end

        if (DATA_WIDTH >= 64) begin
            always_latch begin
                if (rd_en) begin
                    if (block_size == 4) begin
                        if (ENDIANESS) begin
                            reg_rd[63:32]  = {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
                            reg_rd[31:0]   = {MEMX[addr+4], MEMX[addr+5], MEMX[addr+6], MEMX[addr+7]};
                        end else begin
                            reg_rd[63:32]  = {MEMX[addr+7], MEMX[addr+6], MEMX[addr+5], MEMX[addr+4]};
                            reg_rd[31:0]   = {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
                        end
                    end
                    if (block_size == 3) reg_rd[DATA_WIDTH-1:32] = 0;
                end
            end
        end

        if (DATA_WIDTH >= 32) begin
            always_latch begin
                if (rd_en) begin
                    if (block_size == 3) begin
                        if (ENDIANESS)
                            reg_rd[31:0] = {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
                        else
                            reg_rd[31:0] = {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
                    end
                    if (block_size == 2) reg_rd[DATA_WIDTH-1:24] = 0;
                end
            end
        end


        if (DATA_WIDTH >= 24) begin
            always_latch begin
                if (rd_en) begin
                    if (block_size == 2) begin
                        if (ENDIANESS)
                            reg_rd[23:0] = {MEMX[addr], MEMX[addr+1], MEMX[addr+2]};
                        else
                            reg_rd[23:0] = {MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
                    end
                    if (block_size == 1) reg_rd[DATA_WIDTH-1:16] = 0;
                end
            end
        end

        if (DATA_WIDTH >= 16) begin
            always_latch begin
                if (rd_en) begin
                    if (block_size == 1) begin
                        if (ENDIANESS)
                            reg_rd[15:0] = {MEMX[addr], MEMX[addr+1]};
                        else
                            reg_rd[15:0] = {MEMX[addr+1], MEMX[addr]};
                    end
                    if (block_size == 0) reg_rd[DATA_WIDTH-1:8] = 0;
                end
            end
        end

        always_latch begin
            if (rd_en) begin
                if (block_size == 0) begin
                    reg_rd[7:0] = MEMX[addr];
                end
            end
        end
    endgenerate
endmodule
