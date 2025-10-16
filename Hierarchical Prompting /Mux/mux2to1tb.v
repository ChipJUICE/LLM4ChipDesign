`timescale 1ns/1ps

typedef struct packed {
    int errors;
    int errortime;
    int errors_p1y;
    int errortime_p1y;
    int errors_p2y;
    int errortime_p2y;
    int clocks;
} stats;

stats stats1;

module tb;
    reg in1, in2, select;
    wire out;
    integer i;

    // DUT
    mux2to1 dut (
        .in1(in1),
        .in2(in2),
        .select(select),
        .out(out)
    );

    initial begin
        stats1.errors = 0;
        stats1.clocks = 0;

        for (i = 0; i < 8; i = i + 1) begin
            stats1.clocks++;
            {in1, in2, select} = i[2:0];
            #5;
            if (out !== (select ? in2 : in1))
                stats1.errors++;
        end

if (stats1.errors == 0) begin
    $display("All tests passed!");
    $display("passed!");
end else begin
    $display("Mismatches: %0d mismatches in %0d samples", stats1.errors, stats1.clocks);
end

$finish;

    end

    initial begin
        $dumpfile("mux2to1_tb.vcd");
        $dumpvars(0, tb);
    end
endmodule
