`include "consts.vh"
`timescale 1ns / 100ps

`define T_CLK (`T_DELAY_PD * (32*4)) // TODO: calc exact delay
`define T_CYC (`T_CLK * 2)
`define VCD_PATH "vcd/"

string path = `__FILE__;
`define ASM_PATH {path.substr(0, path.len() - 12), "asm/"}

// see max value 2A in the end in ram dmem address d24 (h18)
`define ARR_MAX "find_max_in_array.mem"

// see values in the end in reg_file wr_data at rd_addr=0xB-0xE (x11-x14)
`define BUBBLES "bubble_sort.mem"

// see values in ram each dmem_wr in dmem_wr_data
`define FIBONACCI "fibonacci_sequence.mem"


module tb_riscv #(parameter mem_file = `BUBBLES, parameter FINISH = 1);
    logic clk, res_n;
    integer i, exp;
    
    riscv #(.MEM_FILE("")) dut ( .clk(clk), .res_n(res_n) );

    always #`T_CLK clk = ~clk;

    // Clock cycle counter to terminate simulation
    integer cycle_count;
    always @(posedge clk or negedge res_n) begin
        if (~res_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    always @(posedge clk)
        $strobe("%6d: DEBUG: PC=%3h: INSTRUCTION=%8h: OPCODE=%7b funct3=%3b, rd_addr=0x%0h, rs1_addr=0x%0h, rs2_addr=0x%0h, IMM=0x%0h", $time, dut.pc, dut.instruction, dut.opcode, dut.funct3, dut.rd_addr, dut.rs1_addr, dut.rs2_addr, dut.immediate);

    initial begin
        $dumpfile({`VCD_PATH, mem_file, ".vcd"});
        $dumpvars(0, tb_riscv);
        $monitor("%6d: INFO: res=%0b", $time, res_n);
        dut.instruction_mem.initmem({`ASM_PATH, mem_file});
        clk = 1'b0;
        res_n = 1'b1;
        #`T_CYC res_n = 1'b0;
        #`T_CYC res_n = 1'b1;
        wait (dut.instruction === 'h13);
        @(posedge clk);
        @(posedge clk);
        $display("End of testbench: %s on cycle %0d", mem_file, cycle_count);
        if (FINISH) $finish;
    end
endmodule


module tb_asm_arr;
    integer i, exp;
    tb_riscv #(.mem_file(`ARR_MAX), .FINISH(0)) tb();

    initial begin
        wait (tb.dut.instruction === 'h13);
        @(posedge tb.clk);
        @(posedge tb.clk);

        exp = tb.dut.data_mem.mem_block.MEMX[24];
        if (exp !== 'h2A)
            $display("[tb_riscv] *** ERROR: unexpected memory value %0h", exp);
        else
            $display("PASSED: %0h", exp);
        $finish;
    end
endmodule


module tb_asm_bub;
    integer i, exp;
    tb_riscv #(.mem_file(`BUBBLES), .FINISH(0)) tb();

    initial begin
        wait (tb.dut.instruction === 'h13);
        @(posedge tb.clk);
        @(posedge tb.clk);

        exp = 0;
        for (i = 11; i < 15; i = i + 1)
            exp = {exp, tb.dut.reg_file.reg_mem[i][7:0]};
        if (exp !== 'h09070402)
            $display("[tb_riscv] *** ERROR: unexpected reg file value %0h", exp);
        else
            $display("PASSED: %0h", exp);
        $finish;
    end
endmodule


module tb_asm_fib;
    integer i, exp;
    tb_riscv #(.mem_file(`FIBONACCI), .FINISH(0)) tb();

    initial begin
        wait (tb.dut.instruction === 'h13);
        @(posedge tb.clk);
        @(posedge tb.clk);

        exp = 1;
        for (i = 24; i < 40; i = i + 4)
            exp = {exp, tb.dut.data_mem.mem_block.MEMX[i]};
        if (exp !== 'h080D1522)
            $display("[tb_riscv] *** ERROR: unexpected memory value %0h", exp);
        else
            $display("PASSED: %0h", exp);
        $finish;
    end
endmodule
