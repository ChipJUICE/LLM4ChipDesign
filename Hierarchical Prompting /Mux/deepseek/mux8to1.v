module mux2to1(input wire in1, input wire in2, input wire select, output wire out);
    assign out = select ? in2 : in1;
endmodule
module mux4to1(input [1:0] sel, input [3:0] in, output out);
    wire stage0_out0, stage0_out1;
    mux2to1 mux0(.in1(in[0]), .in2(in[1]), .select(sel[0]), .out(stage0_out0));
    mux2to1 mux1(.in1(in[2]), .in2(in[3]), .select(sel[0]), .out(stage0_out1));
    mux2to1 mux2(.in1(stage0_out0), .in2(stage0_out1), .select(sel[1]), .out(out));
endmodule
module mux8to1(input [2:0] sel, input [7:0] in, output out);
    wire mux4_out0, mux4_out1;
    mux4to1 mux0(.sel(sel[1:0]), .in(in[3:0]), .out(mux4_out0));
    mux4to1 mux1(.sel(sel[1:0]), .in(in[7:4]), .out(mux4_out1));
    mux2to1 mux2(.in1(mux4_out0), .in2(mux4_out1), .select(sel[2]), .out(out));
endmodule
