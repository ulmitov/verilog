if [ -z "$1" ]; then echo "USAGE: my_vvp file [topmodule or testbench file]"; return; fi
if [ -z "$VIRTUAL_ENV_PROMPT" ]; then source ~/Downloads/oss-cad-suite/environment; fi
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
cmd="iverilog -Wall -gspecify -o ./results/${vvpfile}.vvp ${topmodule} ${file}.v"
echo $cmd; echo "vvp ./results/${vvpfile}.vvp"; echo ""
`$cmd`
vvp ./results/${vvpfile}.vvp
