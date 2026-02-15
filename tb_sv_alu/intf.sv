import risc_pkg::*;


interface intf();
    op_enum_alu alu_op;
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [31:0] alu_res;
    logic [31:0] res_exp; // reusing this interface also for ref model
    semaphore ready = new(1);

    modport mod_drv(output alu_op, alu_a, alu_b, input alu_res, res_exp);
    modport mod_mon(input alu_op, alu_a, alu_b, alu_res, res_exp);

    task lock;
        ready.get(1);
    endtask

    task unlock;
        ready.put(1);
    endtask
endinterface

