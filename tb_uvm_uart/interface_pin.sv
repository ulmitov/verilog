import config_pkg::*;


interface interface_pin (input logic pclk, input logic res_n);
    // uart in-ports:
    logic rclk;
    logic sin;
    // uart out-ports:
    logic sout;
    logic baudout;
    logic intr;

    clocking cb_drv @(posedge pclk);
        default input #SETUP_TIME output #HOLDTIME;
        input res_n;
        input sout;
        input baudout;
        input intr;
        input rclk;
        output sin;
    endclocking

    clocking cb_mon @(posedge pclk);
        default input #SETUP_TIME;
        input res_n;
        input sout;
        input baudout;
        input intr;
        input rclk;
        input sin;
    endclocking

    modport mp_drv(clocking cb_drv);
    modport mp_mon(clocking cb_mon);
endinterface
