`timescale 1ns / 100ps
`include "consts.v"

`define T_CLK (`T_DELAY_PD * (32*4)) // TODO: calc exact delay. change to verilog 2005?
`define T_CYC (`T_CLK * 2)

/*
// https://risc-v-cpu-visualizer.vercel.app/assembler bugs in lw and sw funct3 !!!
https://risc-v-cpu-visualizer.vercel.app/help
https://www.cs.cornell.edu/courses/cs3410/2019sp/riscv/interpreter/#

tC > tIFetch + tRFetch + tALU+ tDMem+ tRWB
https://docs.riscv.org/reference/isa/_attachments/riscv-unprivileged.pdf
https://passlab.github.io/CSCE513/notes/lecture07_RISCV_Impl.pdf
https://risc-v-cpu-visualizer.vercel.app/assembler


iverilog -Wall -g2012 -I ../ -o vcd/riscv_tb.vvp -s riscv_32i_tb riscv_32i_tb.sv risc_pkg.sv riscv_32i.sv instruction_mem.sv fetch.sv decode.sv register_file.sv branch_control.sv ../mem.sv alu.sv control.sv ../adder.v ../shift.v ../mux.v
vvp vcd/riscv_tb.vvp
*/
module riscv_32i_tb;
    localparam mem_file = "fibonacci_sequence.mem"; // see the values each dmem_wr in dmem_wr_data
    //localparam mem_file = "find_max_in_array.mem";// see max value 2A in the end at dmem address d24 (h18)
    //localparam mem_file = "bubble_sort.mem";      // see the results in the end of the run in rd=x11-x14.

    logic clk = 1'b0;
    logic res_n = 1'b0;
    
    riscv_32i #(
        .ADDR_WIDTH(8),
        .MEM_FILE({"asm/", mem_file})
    ) dut ( .clk(clk), .res_n(res_n) );

    always #`T_CLK clk = ~clk;

    // Clock cycle counter to terminate simulation
    integer cycle_count = 0;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count > 'h70) $finish;
    end

    initial begin
        $dumpfile({"vcd/", mem_file, ".vcd"});
        $dumpvars(0, riscv_32i_tb);
        $monitor("%d res=%b", $time, res_n);
        $display("START %s", mem_file);
        res_n = 1'b1;
        #`T_CYC res_n = 1'b0;
        #`T_CYC res_n = 1'b1;
    end
endmodule


/*
iverilog -Wall -g2012 -o riscv_inst_tb.vvp -s instruction_mem_tb riscv_32i_tb.sv risc_pkg.sv instruction_mem.sv
vvp riscv_inst_tb.vvp
*/
module instruction_mem_tb;
    //localparam mem_file = "fibonacci_sequence.mem";
    localparam mem_file = "find_maximum_in_array.mem";

    logic imem_req = 1'b0;
    logic [31:0] imem_data;
    logic [31:0] imem_addr = 32'b0;
    
    instruction_memory #( .MEM_FILE(mem_file) ) dut (
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_data(imem_data)
    );

    initial begin
        $dumpfile("instruction_mem_tb.vcd");
        $dumpvars();
        $monitor("%d res=%b", $time, res_n);
        $display("START %s", mem_file);
        imem_req = 1'b1;
        #`T_CYC imem_addr = imem_addr + 4;
	    #800;
        #`T_CYC $finish;
    end
endmodule
