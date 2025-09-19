`timescale 1ns/1ps

module tb;
    reg clk;
    reg reset_n;
    reg data_in;
    reg shift_enable;
    wire [7:0] data_out;

    // DUT instance
    top_module dut (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(data_in),
        .shift_enable(shift_enable),
        .data_out(data_out)
    );

    // Clock generation: 100 MHz (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Test case data
    reg [7:0]  test_case_reset_n     = 8'b00111111;
    reg [7:0]  test_case_data_in     = 8'b01010100;
    reg [7:0]  test_case_shift_enable= 8'b00111010;
    reg [63:0] test_case_data_out    = 64'b00000000000000000000000000000001000000100000010100001010;

    integer i;
    integer errors;
    integer clocks;

    // Test runner
    initial begin
        reset_n      = 1'b1;
        data_in      = 1'b0;
        shift_enable = 1'b0;
        errors       = 0;
        clocks       = 0;

        // Apply 7 samples
        for (i = 0; i < 7; i = i + 1) begin
            reset_n       <= test_case_reset_n[i];
            data_in       <= test_case_data_in[i];
            shift_enable  <= test_case_shift_enable[i];
            @(posedge clk);
            clocks = clocks + 1;

            if (data_out !== test_case_data_out[8*i +: 8]) begin
                errors = errors + 1;
                $display("Error: Test case %0d failed. Expected: %b, Got: %b",
                         i, test_case_data_out[8*i +: 8], data_out);
            end
        end

        if (errors == 0)
            $display("All test cases passed!");

        // Final summary displays (as requested)
        $display("Hint: Total mismatched samples is %1d out of %1d samples", errors, clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", errors, clocks);

        $finish;
    end
endmodule
