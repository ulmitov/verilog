`include "consts.vh"
`timescale 1ns / 100ps
`define VCD "vcd/shift.vcd"


module shift_tb;
    localparam N = 4;
    // longest propagation delay: each shift is number of shift bits amount * mux delay which is 3 gate delays
    localparam T_DELAY = `T_DELAY_PD * 3 * $clog2(N);

    reg [N-1:0] data, din, exp;
    reg [$clog2(N):0] shifts;
    reg signed [N-1:0] sin;
    reg sign, right;
    wire [N-1:0] out;
    integer i;

    shift #(N) uut_r (.right_en(right), .sign(sign), .din(data), .shift_n(shifts), .out(out));

    task check_values;
    begin
        #T_DELAY;
        if (right) begin
            //exp = sign ? $signed(data) >>> shifts : data >> shifts; // iverilog: the conditional operator is mandated to simulate differently than an if-else statement
            if (sign)
                exp = $signed(data) >>> shifts;
            else 
                exp = data >> shifts;
        end else
            exp = data << shifts;
        if (out !== exp)
            $error("%8d: signed=%0b, right=%0b, data=%8b, shifts=%0d (%3b), out=%8b, exp=%8b", $time, sign, right, data, shifts, shifts, out, exp);
    end
    endtask

    initial begin
        $dumpfile(`VCD);
        $dumpvars(0);
        $monitor("%4d: data=%8b, shifts=%0d (%3b), out=%8b", $time, data, shifts, shifts, out);
        $display("Delay time for %0d bit numbers is %0d ns", N, T_DELAY);

        $display("%0d: Test shift left", $time);
        sin = 0;
        sign = 1'b0;
        right = 1'b0;
        for (din = 1; din < (2**N - 1); din = din + 1) begin
            for (shifts = 0; shifts < N; shifts = shifts + 1) begin
                data = din;
                check_values();
            end
        end

        $display("%0d: Test shift right unsigned", $time);
        right = 1'b1;
        for (din = 1; din < (2**N - 1); din = din + 1) begin
            for (shifts = 0; shifts < N; shifts = shifts + 1) begin
                data = din;
                check_values();
            end
        end

        $display("%0d: Test shift right signed", $time);
        sign = 1'b1;
        for (sin = -(2**N/2); sin < 2**N/2 - 1; sin = sin + 1) begin
            for (shifts = 0; shifts < N; shifts = shifts + 1) begin
                data = sin;
                check_values();
            end
        end
        $display("End of testbench: %s", `VCD);
        $finish;
    end
endmodule
