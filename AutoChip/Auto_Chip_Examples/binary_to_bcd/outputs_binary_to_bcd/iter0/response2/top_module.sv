module top_module (
    input  [4:0] binary_input,
    output [7:0] bcd_output
);
    wire [3:0] tens;
    wire [3:0] units;

    // Calculate tens and units
    assign units = binary_input % 10;        // Units digit
    assign tens = binary_input / 10;         // Tens digit

    // Concatenate tens and units to form BCD output
    assign bcd_output = {tens, units};        // Concatenate tens and units

endmodule
