/*
    Constants definitions
*/
`define DEBUG_RUN             // uncomment to see some debug messages
//`define GATE_FLOW_OFF       // uncomment to use data flow logic (should be commented by default)
//`define CONST_DELAYS_OFF    // uncomment to disable delays in combinational and sequential logic

`ifndef CONST_DELAYS_OFF
    `define T_DELAY_FF 2
    `define T_DELAY_PD 1
`else
    `define T_DELAY_FF 0
    `define T_DELAY_PD 0
`endif
