#!/usr/bin/env python3
import fileinput

print("digraph fsm {")

for line in fileinput.input():
    if line.startswith("."):
        continue
    in_bits, from_state, to_state, out_bits = line.split()
    in_bits = in_bits.replace("-", "")
    in_bits = "IN=%s" % int(in_bits) if in_bits else ""
    out_bits = out_bits.replace("-", "")
    out_bits = "OUT=%s" % out_bits if out_bits else ""
    label = [x for x in [in_bits, out_bits] if x]
    label = ",\\n".join(label)
    print('%s -> %s [label="%s"];' % (from_state, to_state, label))
print("}")
