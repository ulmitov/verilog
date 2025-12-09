read_verilog adder_full_n.v
hierarchy -check -top adder_full_n
proc
flatten
techmap
splitnets -ports
opt
clean -purge
stat
write_verilog -noattr synth/adder_full_n_synth.v
show -format svg -prefix synth/adder_full_n adder_full_n
show adder_full_n
