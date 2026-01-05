#!/usr/bin/env bash
# assuming each module has a tb file with the name of module under test with _tb.v
if [[ -z "$VIRTUAL_ENV_PROMPT" ]]; then source ~/Downloads/oss-cad-suite/environment; fi
if [[ -z "$1" ]]; then
    echo -e "USAGE: ./vvp.sh file (without .v) [topmodule name]\nRun first . ./vvp.sh";
else
    file="${1%.*}"
    if [[ -n "$2" ]]; then
        if [[ $2 == *".v"* ]]; then
            # testbench with different name but topmodule with same name
            topmodule="$2"
            vvpfile="${topmodule%.*}"
        else
            # testbench with same name but different topmodule
            topmodule="-s $2 $1_tb.v"
            vvpfile=$2
        fi
    else
        # testbench with same name and same topmodule
        topmodule="-s ${file}_tb ${file}_tb.v"
        vvpfile="${file}_tb"
    fi
    vvpfile=${vvpfile##*/}
    # -g2012 -g2005
    cmd="iverilog -Wall -g2012 -gspecify -o ./results/${vvpfile}.vvp ${topmodule} ${file}.v"
    echo $cmd; echo -e "vvp ./results/${vvpfile}.vvp\n"
    `$cmd`
    rc=$?
    if [[ $rc -eq 0 ]]; then
        vvp ./results/${vvpfile}.vvp
    else
        echo "Run Failed: ${rc}"
    fi
fi
