/*
Sync and async Memory

In the synchronous mode, the read and write operations are totally independent and can be performed simultaneously.
The operation of the memory is fully synchronous with respect to the clock signals, WClock and RClock.
The behavior of the memory is unknown if you write and read at the same addr and signals WClock and RClock are not the same.
The output Q of the memory depends on the time relationship between the write and the read clock.

In the asynchronous mode, the operation of the memory is only synchronous with respect to the clock signal WClock.
Data are read from the RAM memory space at RAddress into Q after some delay when RAddress has changed.
The behavior of the memory is unknown if you write and read at the same addr.
The output Q depends on the time relationship between the write clock and the read addr signal.

f="RAM"; m="RAM";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"
*/
`include "consts.v"
import risc_pkg::*;


module memory #(
    parameter DEPTH      = 2**4, // Memory depth
    parameter DATA_WIDTH = 32,   // Memory data word width
    parameter ADDR_WIDTH = 32,   // Memory address width
    parameter SYNC_READ  = 0,    // 0 is async read (without rclk)
    parameter ENDIANESS  = 0,    // 0 is Little endian
    parameter MEM_FILE   = ""    // machine hex code file path for init
) (
    input logic wclk,/* verilator lint_off UNUSEDSIGNAL */
    input logic rclk,/* verilator lint_on UNUSEDSIGNAL */
    input logic res,
    input logic req,
    input logic wen,
    input logic ren,
    input logic zero_ex,
    input op_enum_dmem_size mem_size,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data
);       
    logic [7:0] MEMX [0:DEPTH-1];    // Each mem address holds 1 byte
    logic [DATA_WIDTH-1:0] temp_rd;
    logic sign;

    task initmem;
        input string path;
        begin
            $display("*** LOADING %s ***", path);
            $readmemh(path, MEMX);
        end
    endtask

    // Init memory
    if (MEM_FILE != "") begin: init_memfile
        initial initmem(MEM_FILE);
    end

    // WR operation: TODO: add ENDIANESS
    always_ff @(posedge wclk) begin
        if (~res & req & wen) begin
            if (mem_size == OP_DMEM_BYTE)
                MEMX[addr] <= #`T_DELAY_FF wr_data[7:0];
            else if (mem_size == OP_DMEM_HALF)
                {MEMX[addr+1], MEMX[addr]} <= #`T_DELAY_FF wr_data[15:0];
            else if (mem_size == OP_DMEM_TRPL)
                {MEMX[addr+2], MEMX[addr+1], MEMX[addr]} <= #`T_DELAY_FF wr_data[23:0];
            else if (mem_size == OP_DMEM_WORD)
                {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]} <= #`T_DELAY_FF wr_data;
        end
    end

    // RD operation
    if (!SYNC_READ) begin: async_read
        always_latch begin
            if (res)
                temp_rd = 0;
            else if (req & ren) begin
                if (ENDIANESS)
                    temp_rd = {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
                else
                    temp_rd = {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
            end
        end
    end else begin: sync_read
        always_ff @(posedge rclk) begin
            if (res)
                temp_rd <= 0;
            else if (req & ren) begin
                if (ENDIANESS)
                    temp_rd <= #`T_DELAY_FF {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
                else
                    temp_rd <= #`T_DELAY_FF {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};
            end
        end
    end

    always_comb begin: set_read_sign_bit
        if (zero_ex)
            sign = 1'b0;
        else begin
            case (mem_size)
                OP_DMEM_BYTE: sign = temp_rd[7];
                OP_DMEM_HALF: sign = temp_rd[15];
                OP_DMEM_TRPL: sign = temp_rd[23];
                default: sign = 1'b0;
            endcase
        end 
    end

    always_comb begin: extend_to_requested_size
        case (mem_size)
            OP_DMEM_BYTE: rd_data = {{24{sign}}, temp_rd[7:0]};
            OP_DMEM_HALF: rd_data = {{16{sign}}, temp_rd[15:0]};
            OP_DMEM_TRPL: rd_data = {{ 8{sign}}, temp_rd[23:0]};
            default: rd_data = temp_rd;
        endcase
    end
endmodule
