interface mem_interface (input logic clk, req);
    logic wen;
    logic ren;
    logic res;
    logic [mem_config::ADDR_WIDTH-1:0] addr;
    logic [mem_config::DATA_WIDTH-1:0] wr_data;
    logic [mem_config::DATA_WIDTH-1:0] rd_data;
    risc_pkg::op_enum_dmem_size blsize;

    clocking cb_drv @(posedge clk);
        default input #mem_config::SETUP_TIME output #mem_config::HOLD_TIME;
        output wen;
        output ren;
        output blsize;
        output addr;
        output wr_data;
        input  rd_data;
        input  res;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #mem_config::SETUP_TIME;
        input res;
        input wen;
        input ren;
        input blsize;
        input addr;
        input wr_data;
        input rd_data;
    endclocking

    modport mp_drv(clocking cb_drv, input clk, input req);
    modport mp_mon(clocking cb_mon, input clk, input req);
/*
    assert_wen_not_x: assert property (@(posedge wclk) disable iff (res) !$isunknown(wen));
    assert_ren_not_x: assert property (@(posedge wclk) disable iff (res) !$isunknown(ren));
    assert_msz_not_x: assert property (@(posedge wclk) disable iff (res) !$isunknown(blsize));
*/
endinterface
