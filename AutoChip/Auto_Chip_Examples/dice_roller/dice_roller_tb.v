`timescale 1ns / 1ps

module tb;
    reg clk;
    reg rst_n;
    reg [1:0] die_select;
    reg roll;
    wire [7:0] rolled_number;

    // DUT instance: renamed to top_module
    top_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .die_select(die_select),
        .roll(roll),
        .rolled_number(rolled_number)
    );

    // Clock generation: 100 MHz (10 ns period)
    always #5 clk = ~clk;

    integer i;
    integer j;
    integer errors;     // total mismatches
    integer clocks;     // total "samples" counted
    reg [31:0] roll_counts [0:20]; // Count occurrences by face value (1..20 used)

    // VCD dump
    initial begin
        $dumpfile("my_design.vcd");
        $dumpvars(0, tb);
    end

    // Testbench stimulus
    initial begin
        clk = 0;
        rst_n = 0;
        die_select = 0;
        roll = 0;

        // Reset and initialization
        #10 rst_n = 1;
        #10 roll = 1;

        errors = 0;
        clocks = 0;

        // Test loop over die types
        for (i = 0; i < 4; i = i + 1) begin
            die_select = i[1:0];

            // Clear roll_counts
            for (j = 0; j <= 20; j = j + 1) begin
                roll_counts[j] = 0;
            end

            // Perform 1000 rolls and count the results
            for (j = 0; j < 1000; j = j + 1) begin
                // Generate a roll pulse (rising edge)
                #10; roll = 0;
                #10; roll = 1;
                #10; roll = 0;
                #10;

                // Check the rolled_number is within the expected range
                case (die_select)
                    2'b00: begin
                        if (rolled_number < 1 || rolled_number > 4) begin
                            $display("Error: Invalid roll result for 4-sided die: %0d (time=%0t)", rolled_number, $time);
                            errors = errors + 1;
                        end
                    end
                    2'b01: begin
                        if (rolled_number < 1 || rolled_number > 6) begin
                            $display("Error: Invalid roll result for 6-sided die: %0d (time=%0t)", rolled_number, $time);
                            errors = errors + 1;
                        end
                    end
                    2'b10: begin
                        if (rolled_number < 1 || rolled_number > 8) begin
                            $display("Error: Invalid roll result for 8-sided die: %0d (time=%0t)", rolled_number, $time);
                            errors = errors + 1;
                        end
                    end
                    2'b11: begin
                        if (rolled_number < 1 || rolled_number > 20) begin
                            $display("Error: Invalid roll result for 20-sided die: %0d (time=%0t)", rolled_number, $time);
                            errors = errors + 1;
                        end
                    end
                endcase

                // Tally counts only for valid range 1..20
                if (rolled_number >= 1 && rolled_number <= 20)
                    roll_counts[rolled_number] = roll_counts[rolled_number] + 1;

                // Count this sample
                clocks = clocks + 1;
            end

            // Print histogram for this die_select
            $display("Results for die_select %b:", die_select);
            case (die_select)
                2'b00: begin
                    integer k4;
                    for (k4 = 1; k4 <= 4; k4 = k4 + 1)
                        $display("  Rolled %0d: %0d times", k4, roll_counts[k4]);
                end
                2'b01: begin
                    integer k6;
                    for (k6 = 1; k6 <= 6; k6 = k6 + 1)
                        $display("  Rolled %0d: %0d times", k6, roll_counts[k6]);
                end
                2'b10: begin
                    integer k8;
                    for (k8 = 1; k8 <= 8; k8 = k8 + 1)
                        $display("  Rolled %0d: %0d times", k8, roll_counts[k8]);
                end
                2'b11: begin
                    integer k20;
                    for (k20 = 1; k20 <= 20; k20 = k20 + 1)
                        $display("  Rolled %0d: %0d times", k20, roll_counts[k20]);
                end
            endcase
        end

        if (errors == 0) begin
            $display("Testbench completed successfully.");
        end else begin
            $display("Testbench completed with %0d errors.", errors);
        end

        // Required final displays
        $display("Hint: Total mismatched samples is %1d out of %1d samples", errors, clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", errors, clocks);

        $finish;
    end
endmodule
