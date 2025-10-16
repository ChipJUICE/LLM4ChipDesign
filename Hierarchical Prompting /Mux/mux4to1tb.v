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
    reg [3:0] in;
    reg [1:0] sel;
    wire out;
    integer i;

    // DUT
    mux4to1 dut (
        .in(in),
        .sel(sel),
        .out(out)
    );

    initial begin
        stats1.errors = 0;
        stats1.clocks = 0;

        for (i = 0; i < 64; i = i + 1) begin
            stats1.clocks++;
            {in, sel} = i[5:0];
            #5;
            if (out !== in[sel])
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
        $dumpfile("mux4to1_tb.vcd");
        $dumpvars(0, tb);
    end
endmodule
