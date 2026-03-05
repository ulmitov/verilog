interface fifo_interface (
    input logic clk,
    input logic res
);
    logic [fifo_config::DATA_WIDTH-1:0] din;
    logic [fifo_config::DATA_WIDTH-1:0] dout;
    logic push;
    logic pull;
    logic empty;
    logic full;

    clocking cb_drv @(posedge clk);
        /*
        Input Skew: The input signals will be sampled 2 times unit before the clock edge.
        Output Skew: Delays the driving of output signals by a specified time relative to clk edge.
        default: input #1step output #0;
        */
        default input #fifo_config::SETUP_TIME output #(fifo_config::HOLD_TIME+1);
        output push;
        output pull;
        output din;
        input dout;
        input empty;
        input full;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #(fifo_config::SETUP_TIME+1);
        input push;
        input pull;
        input din;
        input dout;
        input empty;
        input full;
    endclocking
    
    // actually if DUT is pure Verilog dont need these:
    modport DRIVER_MP(clocking cb_drv, input clk, input res);
    modport MONITOR_MP(clocking cb_mon, input clk, input res);

    /* ASSERTIONS */
    static int THRESH_FULL = fifo_config::FIFO_DEPTH-1;
    static int THRESH_NONE = 0;
    int count;
    always_ff @(posedge clk) begin
        if (res) count <= 0;
        else if (push ^ pull) begin
            // not parallel
            if (push & count != THRESH_FULL) count <= count + 1;
            if (pull & count != THRESH_NONE) count <= count - 1;
        end else if (push | pull) begin
            // in parallel
            if (count == THRESH_NONE) count <= count + 1;
            if (count == THRESH_FULL) count <= count - 1;
        end
        $display("%t D COUNT=%0d", $time, count);
        $strobe("%t S COUNT=%0d", $time, count);
    end

    assert_empty_on_res: assert property (
        @(negedge res) res |-> empty
    ) else log("assert_empty_on_res");

    assert_unfull_on_res: assert property (
        @(negedge res) res |-> ~full
    ) else log("assert_unfull_on_res");

    assert_empty_full: assert property (
        @(posedge clk) disable iff (res)
            ~(empty & full)
    ) else log("assert_empty_full");

    assert_empty_to_high: assert property (
        @(posedge clk) disable iff (res)
            (count == THRESH_NONE) |-> empty
    ) else log("assert_empty_to_high");

    assert_empty_to_low: assert property (
        @(posedge clk) disable iff (res)
            (count > THRESH_NONE) |-> ~empty
    ) else log("assert_empty_to_low");

    assert_empty_stable: assert property (
        @(posedge clk) disable iff (res)
            (empty & pull & ~push) |=> $stable(empty)
    ) else log("assert_empty_stable");

    assert_full_to_high: assert property (
        @(posedge clk) disable iff (res)
            (count >= THRESH_FULL) |-> full
    ) else log("assert_full_to_high");

    assert_full_to_low: assert property (
        @(posedge clk) disable iff (res)
            (count < THRESH_FULL) |-> ~full
    ) else log("assert_full_to_low");

    assert_full_stable: assert property (
        @(posedge clk) disable iff (res)
            (full & push & ~pull) |=> $stable(full)
    ) else log("assert_full_stable");

    function void log(string name);
        $error("[AssertFailed] %s: count=%0d empty=%0b, full=%0b", name, $sampled(count), $sampled(empty), $sampled(full));
    endfunction
endinterface
