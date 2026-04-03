lint:
	verilator --lint-only -Wall $(TOP)
lint-all:
	verilator --lint-only -Wall $$(ls *.*v* | xargs)
vvp:
	iverilog -Wall -g2005 -gspecify -o ./vcd/$(TOP)_tb.vvp -s $(TOP)_tb testbench/$(TOP)_tb.v $(TOP).v && vvp ./vcd/$(TOP)_tb.vvp
ver:
	verilator -Wno-lint --trace-vcd --binary --timing -I../modules/ --top $(TOP)_tb --cc testbench/$(TOP)_tb.v $(TOP).v && ./obj_dir/V$(TOP)_tb
confirm:
	@read -p "Continue to next test? [y/N] " ans && [ $${ans:-N} = y ] || (echo "Aborted."; exit 1)
clean:
	rm ./vcd/*.vvp
