`include "consts.vh"
import risc_pkg::*;


module riscv #(
    parameter XLEN = RISCV_XLEN,
    parameter MEM_DEPTH = 512,          // Data memory depth
    parameter MEM_FILE = ""             // Machine code to load on init
) (
    input logic clk,
    input logic res_n,
    input logic [XLEN-1:0] dbus_rd_data,
    output logic [XLEN-1:0] dbus_wr_data,
    output logic [31:0] dmem_addr,
    output logic dmem_req,
    output logic dmem_wr
);
    logic [31:0] imem_addr;
    logic [INST_LEN-1:0] instruction;
    logic [XLEN-1:0] mem_rd_data, dmem_rd_data;
    logic [XLEN-1:0] rs1_data, rs2_data, rf_wr_data;
    logic [4:0] rd_addr, rs1_addr, rs2_addr;
    logic imem_req;
    logic rf_wr_en;
    logic dmem_zero_ex;
    op_enum_dmem_size dmem_size;

    // TODO: make an address decoder, move memory outside, add AHB...
    assign mem_rd_data = (dmem_addr >= DMEM_BASE_ADDRESS && dmem_addr < DMEM_BASE_ADDRESS + MEM_DEPTH) ? dmem_rd_data : dbus_rd_data;

    riscv_core #(.XLEN(XLEN)) core (
        .clk(clk),
        .res_n(res_n),
        .instruction(instruction),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .dmem_rd_data(mem_rd_data),
        // outputs:
        .pc(imem_addr),
        .imem_req(imem_req),
        .rf_wr_en(rf_wr_en),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rf_wr_data(rf_wr_data),
        .dmem_wr_data(dbus_wr_data),
        .dmem_zero_ex(dmem_zero_ex),
        .dmem_req(dmem_req),
        .dmem_wr(dmem_wr),
        .dmem_size(dmem_size),
        .dmem_addr(dmem_addr)
    );


    memory #(
        `ifdef DEBUG_RUN
        .DEPTH(2**14),       // 2**10/4 = 256 instructions
        `else
        .DEPTH(2**14),      // 16kb, 4k instructions
        `endif
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .MEM_FILE(MEM_FILE),
        .ENDIANESS(1)       // images in big endian
    ) instruction_mem (
        .wen(), .wr_data(),
        .wclk(clk),
        .res(~res_n),
        .req(1'b1),
        .addr(imem_addr),
        .blsize(op_enum_dmem_size'(OP_DMEM_WORD)),
        .ren(imem_req),
        // outputs:
        .rd_data(instruction)
    );


    register_file #(XLEN) reg_file (
        .clk(clk),
        .res_n(res_n),
        .rf_wr_en(rf_wr_en),
        .rd_addr(rd_addr),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        // outputs:
        .rs2_data(rs2_data),
        .wr_data(rf_wr_data)
    );


    data_memory #(
        .DATA_WIDTH(XLEN),
        .DEPTH(MEM_DEPTH),
        .ADDR_WIDTH(32),
        .ENDIANESS(0)
    ) data_mem (
        .clk(clk),
        .res(~res_n),
        .ren(1'b1),
        .wen(dmem_wr),
        .req(dmem_req),
        .addr(dmem_addr),
        .blsize(dmem_size),
        .zero_ex(dmem_zero_ex),
        .wr_data(dbus_wr_data),
        // outputs:
        .rd_data(dmem_rd_data)
    );
endmodule
