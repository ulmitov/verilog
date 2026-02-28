/* SEE README HOW TO RUN */
`include "consts.v"
`timescale 1ns / 100ps

`define T_CLK (`T_DELAY_PD * (32*4)) // TODO: calc exact delay
`define T_CYC (`T_CLK * 2)


module riscv_tb;
    //localparam mem_file = "fibonacci_sequence.mem";   // see values in ram each dmem_wr in dmem_wr_data
    //localparam mem_file = "find_max_in_array.mem";    // see max value 2A in the end at ram dmem address d24 (h18)
    localparam mem_file = "bubble_sort.mem";            // see values in the end in reg_file wr_data at rd_addr=0xB-0xE (x11-x14)

    logic clk, res_n;
    
    riscv #(.MEM_FILE("")) dut ( .clk(clk), .res_n(res_n) );

    always #`T_CLK clk = ~clk;

    // Clock cycle counter to terminate simulation
    integer cycle_count;
    always @(posedge clk or negedge res_n) begin
        if (~res_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
        if (cycle_count > 'h70) begin
            $display("TEST %s FINISHED", mem_file);
            $finish;
        end
    end

    always @(posedge clk)
        $strobe("%6d: DEBUG: PC=%3h: INSTRUCTION=%8h: OPCODE=%7b funct3=%3b, rd_addr=0x%0h, rs1_addr=0x%0h, rs2_addr=0x%0h, IMM=0x%0h", $time, dut.pc, dut.instruction, dut.opcode, dut.funct3, dut.rd_addr, dut.rs1_addr, dut.rs2_addr, dut.immediate);

    initial begin
        $dumpfile({"vcd/", mem_file, ".vcd"});
        $dumpvars(0, riscv_tb);
        $monitor("%6d: INFO: res=%0b", $time, res_n);
        dut.instruction_mem.initmem({"asm/", mem_file});
        clk = 1'b0;
        res_n = 1'b1;
        #`T_CYC res_n = 1'b0;
        #`T_CYC res_n = 1'b1;
    end
endmodule
