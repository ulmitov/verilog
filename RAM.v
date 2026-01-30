/*
Synchronous/Asynchronous RAM
https://yosyshq.readthedocs.io/projects/yosys/en/0.37/CHAPTER_Memorymap.html

In the synchronous mode, the read and write operations are totally independent and can be performed simultaneously.
The operation of the RAM is fully synchronous with respect to the clock signals, WClock and RClock.
Data of value Data are written to the WAddress of the RAM memory space on the rising (RISE) or falling (FALL) edge
of the clock WClock (WCLK_EDGE). 
Data are read from the RAM memory space at RAddress into Q on the rising (RISE) or falling (FALL) edge
of the clock signal RClock (RCLK_EDGE).
The behavior of the RAM is unknown if you write and read at the same address and signals WClock and RClock are not the same.
The output Q of the RAM depends on the time relationship between the write and the read clock.

In the asynchronous mode, the operation of the RAM is only synchronous with respect to the clock signal WClock.
Data of value Data are written to the WAddress of the RAM memory space on the rising (RISE) or falling (FALL) edge
of the clock signal WClock (WCLK_EDGE). 
Data are read from the RAM memory space at RAddress into Q after some delay when RAddress has changed.
The behavior of the RAM is unknown if you write and read at the same address.
The output Q depends on the time relationship between the write clock and the read address signal.

The write enable (WE) and read enable (RE) signals are active high request signals for writing and reading,
respectively; you may choose not to use them.


*** Port Description ***
PortName    Size    Type    Req/Opt     Function

Data        WIDTH   Input   Req.        Input Data
WE          1       input   Opt.        Write Enable
RE          1       input   Opt.        Read Enable
WClock      1       input   Req.        Write clock
RClock      1       input   Opt.        Read clock
Q           WIDTH   output  Req.        Output Data


*** Parameter Description ***
WIDTH
Word length of Data and Q

Depth:
Number of RAM words

WE_POLARITY: 1 (Used) 0 (Not Used)
WE can be active high or not used

RE_POLARITY: 1 (Used) 0 (Not Used)
RE can be active high or not used

WCLK_EDGE: RISE FALL
WClock can be rising or falling

RCLK_EDGE: RISE FALL NONE
RClock can be rising, falling, or not used


f="RAM"; m="RAM";
yosys -p "read_verilog ${f}.v; hierarchy -check -top $m; proc; opt; clean; show -format svg -prefix synth/${m} ${m}; show ${m}"

*/
`include "consts.v"

`define DATA_WIDTH 8        // Mem data word width
`define DATA_DEPTH 2**4     // Mem depth


module RAM #(
    parameter WIDTH = `DATA_WIDTH,  // Memory data word width
    parameter DEPTH = `DATA_DEPTH,
    parameter WCLK_EDGE = "RISE",   // RISE, FALL
    parameter RCLK_EDGE = "NONE",   // RISE, FALL, NONE
    parameter WE_POLARITY = 1,      // 0 is none
    parameter RE_POLARITY = 1,      // 0 is none
    parameter MEM_FILE = ""
) (
    input wclk, /* verilator lint_off UNUSEDSIGNAL */ 
    input rclk,
    input res, /* verilator lint_on UNUSEDSIGNAL */
    input wen,
    input ren,
    input [WIDTH-1:0] data,
    input [$clog2(DEPTH)-1:0] address,
    output reg [WIDTH-1:0] Q
    //,output wire F_WDONE
);
    reg [WIDTH-1:0] MEMX [DEPTH-1:0];
    integer i;

    initial begin
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, MEMX);
        else
            for (i = 0; i < DEPTH; i = i + 1) MEMX[i] = {WIDTH{1'b1}};
    end
    //TODO: assign F_WDONE = wen ? MEMX[address] == data : 0;
    //TODO: reset is unsed for now

    // write operation
    if (WCLK_EDGE == "RISE") begin: wop_rise
        always @(posedge wclk) begin
            if (wen | !WE_POLARITY)
                #`T_DELAY_FF MEMX[address] <= data;
        end
    end else begin: wop_fall
        always @(negedge wclk) begin
            if (wen | !WE_POLARITY)
                #`T_DELAY_FF MEMX[address] <= data;
        end
    end

    // read operation
    if (RCLK_EDGE == "RISE") begin: rop_rise
        always @(posedge rclk) begin
            if (ren | !RE_POLARITY) Q <= MEMX[address];
        end
    end else if (RCLK_EDGE == "FALL") begin: rop_fall
        always @(negedge rclk) begin
            if (ren | !RE_POLARITY) Q <= MEMX[address];
        end
    end else begin: rop_async
        always @(*) begin
            // this will synth DFF's and MUXes
            Q = (ren | !RE_POLARITY) ? MEMX[address] : {WIDTH{1'bX}};
            // this will synth latches and if ren is 0 then it will return previously stored Q
            //if (ren || !RE_POLARITY) Q = MEMX[address];
            //else Q = {{WIDTH{1'bX}}};
        end
    end
endmodule
