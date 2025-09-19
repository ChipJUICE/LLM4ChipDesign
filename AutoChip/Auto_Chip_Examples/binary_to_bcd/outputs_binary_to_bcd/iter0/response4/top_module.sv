module top_module (
    input  [4:0] binary_input,
    output [7:0] bcd_output
);
    
    wire [3:0] tens;
    wire [3:0] units;

    // Calculate the units and tens using division and modulo operations
    assign units = binary_input % 10;
    assign tens = binary_input / 10;

    // Concatenate tens and units to form the BCD output
    assign bcd_output = {tens, units};

endmodule
