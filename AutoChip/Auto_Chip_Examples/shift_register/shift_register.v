/*
You are generating synthesizable Verilog-2001.
Output ONLY the complete Verilog-2001 code ending with endmodule.
Do not generate a testbench.
Do not include markdown fences, explanations, or prose.

Write a module with the following specification:

Module name:
top_module

Ports (must use these exact names):

clk (input wire) → clock input

reset_n (input wire) → active-low reset

data_in (input wire) → 1-bit serial data input (not used in this version)

shift_enable (input wire) → shift enable (not used in this version)

data_out (output reg [7:0]) → 8-bit parallel data output

Behavior:

At initialization, preload data_out = 8'h0A to avoid unknown (x) on the first sample.

On the rising edge of clk or falling edge of reset_n:

If reset_n is low, clear data_out to all zeros.

Else, unconditionally perform a logical right shift with zero fill:
data_out <= {1'b0, data_out[7:1]}.

Do not gate shifting with shift_enable.

End the code with endmodule.

*/