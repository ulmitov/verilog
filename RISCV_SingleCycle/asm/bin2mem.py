#!/usr/bin python3
import sys

with open(sys.argv[-1], "r") as f:
    bintxt = f.readlines()

big_endian = 0
hextxt = []

for l in bintxt:
    l = f"0x{int(l, 2):0{8}x}"[2:]      # f"0x{value:0{padding}x}"
    l = [l[0:2], l[2:4], l[4:6], l[6:]]
    if big_endian:
        l = reversed(l)
    hextxt.append(" ".join(l))

new = sys.argv[-1] +".mem"
print(new)
with open(new, "w") as f:
    bintxt = f.write("\n".join(hextxt))
