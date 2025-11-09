`timescale 1ns/1ps
module tb_echotest;
  // clock and setup
  reg i_clk = 0;
  reg [30:0] i_setup = 31'd868;
  // loopback wire: connect TX back to RX
  wire o_uart_tx;
  wire i_uart_rx = o_uart_tx;

  // Instantiate DUT (named port connections to avoid order issues)
  echotest dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx)
  );

  // Clock: 10 ns period (100 MHz) — arbitrary, matches many test files
  always #5 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_echotest.vcd");
    $dumpvars(0, tb_echotest);

    // Run long enough to see activity from the DUT
    #20000;

    $display("Simulation finished.");
    $finish;
  end
endmodule
