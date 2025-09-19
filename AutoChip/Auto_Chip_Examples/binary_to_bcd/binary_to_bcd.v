/*
Create a Verilog module named top_module that is compatible with iverilog. 

The module should have a 5-bit input, binary_input, to handle values from 0 to 31. 
It must also have an 8-bit output, bcd_output, where the most significant nibble (bits 7 down to 4) represents the tens digit and the least significant nibble (bits 3 down to 0) represents the units digit of the decimal equivalent.

The implementation should use division and modulo operations to perform the conversion. 
The intermediate results should be assigned to wires, and the final bcd_output should be a concatenation of the lower 4 bits of the tens and units wires.

The module declaration should be as follows:
*/

module top_module (
    input  [4:0] binary_input,
    output [7:0] bcd_output
);

// Module body goes here

endmodule