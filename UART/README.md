# UART module

- Glitch resistive UART module
- N=5 to 8 data bits (TBD)
- M=1 or 2 stop bits
- OSR=Programmable oversample rate by 4, 8, 16, 32
- PAR=None, even, odd or forced parity bit

![clock_div.png](./dir/uart_tb_2stopbits.png)


# Baud generator
The Baud clock is genrated in `clock_divisor.sv`.
This module produces an output clock based on the input clock frequency divided by a Divisor number.
For example for 100Mhz clock, for baud rate 9600bps, 16 samples per clock, with a parity bit and two stop bits (+3 bits),
set divisor to: 100 / (16 * 9600 * (8+2+1/8)) which is a rounded 470.

`DIVIDER = Freq / ((M + PAR + N)/8) × OSR × Brate)`

![clock_div.png](./dir/clock_div.png)