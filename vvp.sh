#!/usr/bin/env bash
# assuming each module has a tb file with the name of module under test with _tb.v
export UVM_HOME="~/dev/sda6/uvm-core-2020.3.1/src"
if [[ -z "$VIRTUAL_ENV_PROMPT" ]]; then source ~/dev/sda6/oss-cad-suite/environment; fi
if [[ -z "$1" ]]; then
    echo -e "USAGE: ./vvp.sh testbench_name [testbench_file verilog_files]\nRun first . ./vvp.sh";
else
    topmodule=$1
    vvpfile="${topmodule%.*}"
    if [[ -n "$2" ]]; then
        if [[ -n "$3" ]]; then
            # 3 or more args - tbname tbfile.sv module1.v module2.v...
            modules="-s ${topmodule} ${@:2}"
            dut_file=${@:3}
        else
            # only 2 args
            dut_file=$2
            if [[ "$dut_file" == *"_tb"* ]]; then
                # tbname tb_file.v
                dut_file=${dut_file//"_tb"/""}
                modules="-s ${topmodule} $2 ${dut_file}"
            else
                # tbname module.v
                tb="${2%.*}"
                if [ -f "${tb}_tb.sv" ]; then
                    tb="${tb}_tb.sv"
                else
                    tb="${tb}_tb.v"
                fi
                modules="-s ${topmodule} ${tb} ${dut_file}"
            fi
        fi
    else
        # only one arg received - testbench is with same name and same topmodule
        dut_file=${vvpfile%"_tb"}
        if [ -f "${dut_file}.sv" ]; then
            dut_file="${dut_file}.sv"
        else
            dut_file="${dut_file}.v"
        fi
        if [ ! -f "${topmodule}" ]; then
            if [ -f "${topmodule}.sv" ]; then
                tb="${topmodule}.sv"
            else
                tb="${topmodule}.v"
            fi
        fi
        modules="-s ${topmodule} ${tb} ${dut_file}"
    fi
    vvpfile=${vvpfile##*/}
    if [[ "$modules" == *".sv"* ]]; then sysv="-g2012"; else sysv="-g2005"; fi
    if [ -e "./vcd" ]; then simdir="./vcd/"; else simdir=""; fi
    cmd="iverilog -Wall ${sysv} -gspecify -o ${simdir}${vvpfile}.vvp ${modules}"
    echo $cmd; `$cmd`
    rc=$?
    if [[ $rc -eq 0 ]]; then
        echo -e "\nverilator --lint-only -Wall -cc --timing ${dut_file}"
        verilator --lint-only -Wall -Wno-IMPORTSTAR -cc --timing ${dut_file}
        echo -e "\nvvp ${simdir}${vvpfile}.vvp";
        vvp ${simdir}${vvpfile}.vvp
    else
        echo "Run Failed: ${rc}"
    fi
fi
