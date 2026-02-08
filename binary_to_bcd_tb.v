`timescale 1ns / 1ps

module tb_binary_to_bcd_converter;

reg        clk;
reg        enable;
reg [4:0]  binary_input;
wire [7:0] bcd_output;

binary_to_bcd_converter uut (
    .clk(clk),
    .enable(enable),
    .binary_input(binary_input),
    .bcd_output(bcd_output)
);

integer i;
reg [4:0] test_binary;
reg [7:0] expected_bcd;
reg [7:0] last_bcd;

// Clock generation: 10 ns period
initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $display("Testing Binary-to-BCD Converter with enable...");

    enable       = 0;
    binary_input = 0;
    last_bcd     = 0;

    // First, verify update when enable = 1
    for (i = 0; i < 32; i = i + 1) begin
        test_binary   = i;
        binary_input  = test_binary;

        expected_bcd[3:0] = test_binary % 10;
        expected_bcd[7:4] = test_binary / 10;

        // Pulse enable for one clock edge
        enable = 1;
        @(posedge clk); // wait for clock edge to register output
        #1;             // small delay for nonblocking assignments

        if (bcd_output !== expected_bcd) begin
            $display("Error (enable=1): bin=%0d, expected BCD=8'b%0b, got=8'b%0b",
                     test_binary, expected_bcd, bcd_output);
            $finish;
        end

        last_bcd = bcd_output;

        // Disable and change input; output should hold
        enable       = 0;
        binary_input = test_binary + 1;
        @(posedge clk);
        #1;

        if (bcd_output !== last_bcd) begin
            $display("Error (enable=0): output changed. prev BCD=8'b%0b, got=8'b%0b",
                     last_bcd, bcd_output);
            $finish;
        end
    end

    $display("All test cases passed with enable behavior!");
    $finish;
end

// VCD dump
initial begin
    $dumpfile("my_design.vcd");
    $dumpvars(0, tb_binary_to_bcd_converter);
end

endmodule
