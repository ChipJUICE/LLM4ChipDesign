module top_module (
    input  [4:0] binary_input,
    output [7:0] bcd_output
);

wire [3:0] tens;
wire [3:0] units;

assign units = binary_input % 10;
assign tens = binary_input / 10;

assign bcd_output = {tens, units};

endmodule
