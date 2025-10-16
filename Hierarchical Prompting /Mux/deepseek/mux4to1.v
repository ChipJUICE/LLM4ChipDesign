module mux2to1(input wire in1, input wire in2, input wire select, output wire out);
    assign out = select ? in2 : in1;
endmodule
module mux4to1(input [1:0] sel, input [3:0] in, output wire out);
    wire mux0_out, mux1_out;
    
    // First layer selects between pairs
    mux2to1 mux0(.in1(in[0]), .in2(in[1]), .select(sel[0]), .out(mux0_out));
    mux2to1 mux1(.in1(in[2]), .in2(in[3]), .select(sel[0]), .out(mux1_out));
    
    // Second layer selects between first layer outputs
    mux2to1 mux_final(.in1(mux0_out), .in2(mux1_out), .select(sel[1]), .out(out));
endmodule
