module tb_dice_roller();
    reg clk;
    reg rst_n;
    reg [1:0] die_select;
    reg roll;
    wire [7:0] rolled_number;
    wire [9:0] running_sum;   // observe running_sum

    dice_roller dut (
        .clk          (clk),
        .rst_n        (rst_n),        // FIXED: match DUT port name
        .die_select   (die_select),
        .roll         (roll),
        .rolled_number(rolled_number),
        .running_sum  (running_sum)
    );

    // Clock generation
    always begin
        #5 clk = ~clk;
    end

    integer i;
    integer j;
    integer error_count;
    reg [31:0] roll_counts [0:20];

    // variables to check running_sum against last 4 rolls
    integer k;
    reg [7:0] last4 [0:3];
    integer idx;
    integer expected_sum;

    // Testbench stimulus
    initial begin

        clk       = 0;
        rst_n     = 0;
        die_select= 0;
        roll      = 0;

        for (k = 0; k < 4; k = k + 1)
            last4[k] = 0;           // init last4 history

        #10 rst_n = 1;
        #10 roll  = 1;

        error_count = 0;

        for (i = 0; i < 4; i++) begin
            die_select = i;

            for (j = 1; j <= 20; j++) begin
                roll_counts[j] = 0;
            end

            for (k = 0; k < 4; k = k + 1)
                last4[k] = 0;       // clear history per die

            idx = 0;                // circular index for last4

            // Perform 1000 rolls and count the results
            for (j = 0; j < 1000; j++) begin
                #10;
                roll = 0;
                #10;
                roll = 1;
                #10;
                roll = 0;
                #10;

                // Check the rolled_number is within the expected range
                case (die_select)
                    2'b00: begin
                        if (rolled_number < 1 || rolled_number > 4) begin
                            $display("Error: Invalid roll result for 4-sided die: %d", rolled_number);
                            error_count = error_count + 1;
                        end
                    end
                    2'b01: begin
                        if (rolled_number < 1 || rolled_number > 6) begin
                            $display("Error: Invalid roll result for 6-sided die: %d", rolled_number);
                            error_count = error_count + 1;
                        end
                    end
                    2'b10: begin
                        if (rolled_number < 1 || rolled_number > 8) begin
                            $display("Error: Invalid roll result for 8-sided die: %d", rolled_number);
                            error_count = error_count + 1;
                        end
                    end
                    2'b11: begin
                        if (rolled_number < 1 || rolled_number > 20) begin
                            $display("Error: Invalid roll result for 20-sided die: %d", rolled_number);
                            error_count = error_count + 1;
                        end
                    end
                endcase

                roll_counts[rolled_number] = roll_counts[rolled_number] + 1;

                // update software model of last 4 rolls
                last4[idx] = rolled_number;
                idx = (idx + 1) % 4;

                // compute expected running sum and compare
                expected_sum = last4[0] + last4[1] + last4[2] + last4[3];
                if (running_sum !== expected_sum[9:0]) begin
                    $display("Error: running_sum mismatch. Die=%b roll=%0d expected_sum=%0d got=%0d",
                             die_select, rolled_number, expected_sum, running_sum);
                    error_count = error_count + 1;
                end
            end

            $display("Results for die_select %b:", die_select);
            for (j = 1; j <= 20; j++) begin
                if (roll_counts[j] > 0) begin
                    $display("  Rolled %d: %d times", j, roll_counts[j]);
                end
            end
        end

        if (error_count == 0) begin
            $display("Testbench completed successfully.");
        end else begin
            $display("Testbench completed with %d errors.", error_count);
        end

        $finish;
    end

    reg vcd_clk;
    initial begin
        vcd_clk = 0;
        $dumpfile("my_design.vcd");
        $dumpvars(0, tb_dice_roller);
    end

    always #5 vcd_clk = ~vcd_clk;

endmodule
