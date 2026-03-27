`define DEBUG 1

//`define DELAYS_OFF          // uncomment to apply delays to combinational and sequential logic

`ifndef DELAYS_OFF
    `define T_DELAY_FF 2
    `define T_DELAY_PD 1
`else
    `define T_DELAY_FF 0
    `define T_DELAY_PD 0
`endif

`define GATEFLOW 1        // uncomment to use gate flow logic

//`define BEHAVIORAL 1      // uncomment to use behavioral flow logic
