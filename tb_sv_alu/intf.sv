interface intf #(parameter XLEN = RISCV_XLEN) (input logic clk);
    semaphore ready = new(1);
    op_enum_alu alu_op;
    logic [XLEN-1:0] alu_a;
    logic [XLEN-1:0] alu_b;
    logic [XLEN-1:0] alu_res;
    logic [XLEN-1:0] res_exp; // using this interface also for the Reference model

    modport mod_drv(output alu_op, alu_a, alu_b, input alu_res, res_exp);
    modport mod_mon(input alu_op, alu_a, alu_b, alu_res, res_exp);

    task lock;
        ready.get(1);
    endtask
    task unlock;
        ready.put(1);
    endtask
endinterface
