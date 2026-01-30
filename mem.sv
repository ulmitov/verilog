/*
Sync and async Memory (RAM)

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
import risc_pkg::*;
`include "consts.v"

`define DATA_WIDTH 8        // Mem data word width (8 is minimum)
`define DATA_DEPTH 2**4     // Mem depth


module mem #(
    parameter WIDTH = `DATA_WIDTH,  // Memory data word width
    parameter DEPTH = `DATA_DEPTH,
    parameter SYNC_READ = 0,        // 0 is async read (without rclk)
    parameter MEM_FILE = "",
    parameter ENDIANESS = 0         // 0 is Little endian
) (
    input logic wclk,
    input logic rclk,
    input logic res,
    input logic req,
    input logic wen,
    input logic ren,
    input logic zero_ex,
    input op_dmem_size mem_size,
    input logic [$clog2(DEPTH)-1:0] addr,
    input logic [31:0] wr_data,
    output logic [31:0] rd_data
    //,output wire F_WDONE
);
    logic [WIDTH-1:0] MEMX [DEPTH-1:0];
    logic [WIDTH-1:0] temp_rd;
    logic sign;
    integer i;
    //TODO: assign F_WDONE = wen ? MEMX[addr] == wr_data : 0;

    // Init memory
    if (MEM_FILE != "") begin: memfile_init
        initial begin
            $readmemh(MEM_FILE, MEMX);
        end
    end else begin: ram_init
        always_ff @(posedge res) begin
            if (res) begin
                for (i = 0; i < DEPTH; i = i + 1)
                    MEMX[i] <= {WIDTH{1'b1}};
            end
        end
    end

    // WR operation
    always_ff @(posedge wclk) begin
        if (req & wen) begin
            if (mem_size == OP_DMEM_BYTE)
                MEMX[addr] <= #`T_DELAY_FF wr_data[7:0];
            else if (mem_size == OP_DMEM_HALF)
                {MEMX[addr+1], MEMX[addr]} <= #`T_DELAY_FF wr_data[15:0];
            else
                {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]} <= #`T_DELAY_FF wr_data;
        end
    end

    // RD operation
    // set the sign bit
    always_comb begin
        if (~zero_ex) begin
            case (mem_size)
                OP_DMEM_BYTE: sign = temp_rd[7];
                OP_DMEM_HALF: sign = temp_rd[15];
                default: sign = 1'b0;
            endcase
        end else
            sign = 1'b0;
    end

    if (!SYNC_READ) begin: async_read
        if (ENDIANESS)
            assign #`T_DELAY_PD temp_rd = {MEMX[addr], MEMX[addr+1], MEMX[addr+2], MEMX[addr+3]};
        else
            assign #`T_DELAY_PD temp_rd = {MEMX[addr+3], MEMX[addr+2], MEMX[addr+1], MEMX[addr]};

        // sign extension
        always_comb begin
            // this will synth DFF's and MUXes
            //rd_data = #`T_DELAY_PD ren ? MEMX[addr] : {WIDTH{1'bX}};
            // this will synth latches and if ren is 0 then it will return previously stored Q
            //if (ren) rd_data = MEMX[addr];
            //else rd_data = {{WIDTH{1'bX}}};
            if (req & ren) begin
                case (mem_size)
                    OP_DMEM_BYTE: rd_data = {{24{sign}}, temp_rd[7:0]};
                    OP_DMEM_HALF: rd_data = {{16{sign}}, temp_rd[15:0]};
                    default: rd_data = temp_rd;
                endcase
            end else
                rd_data = {WIDTH{1'b1}};
        end
    end else begin: sync_read
        // TODO: add here the mem size logic
        always_ff @(posedge rclk) begin
            if (req & ren)
                rd_data <= #`T_DELAY_FF MEMX[addr];
        end
    end
endmodule
