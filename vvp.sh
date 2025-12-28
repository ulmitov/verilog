#!/usr/bin/env bash
if [[ -z "$VIRTUAL_ENV_PROMPT" ]]; then source ~/Downloads/oss-cad-suite/environment; fi
if [[ -z "$1" ]]; then
    echo -e "USAGE: ./vvp.sh file [topmodule or testbench file]\nRun first . ./vvp.sh";
else
    file="${1%.*}"
    if [[ -n "$2" ]]; then
        if [[ $2 == *".v"* ]]; then
            # testbench is in separate file with different name
            topmodule="$2"
            vvpfile="${topmodule%.*}"
        else
            # testbench is in same file
            topmodule="-s $2"
            vvpfile=$2
        fi
    else
        # given only main module file => testbench is in separate file with same name
        topmodule="${file}_tb.v"
        vvpfile="${file}_tb"
    fi
    vvpfile=${vvpfile##*/}
    # -g2012 -g2005
    cmd="iverilog -Wall -gspecify -o ./results/${vvpfile}.vvp ${topmodule} ${file}.v"
    echo $cmd; echo -e "vvp ./results/${vvpfile}.vvp\n"
    `$cmd`
    rc=$?
    if [[ $rc -eq 0 ]]; then
        vvp ./results/${vvpfile}.vvp
    else
        echo "Run Failed: ${rc}"
    fi
fi
