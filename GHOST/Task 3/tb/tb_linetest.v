`timescale 1ns/1ps
module tb_linetest;
  reg i_clk = 0;
  reg [30:0] i_setup = 31'd868;
  wire o_uart_tx;
  wire i_uart_rx = o_uart_tx; // simple loopback for the line test

  linetest dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx)
  );

  always #5 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_linetest.vcd");
    $dumpvars(0, tb_linetest);

    #20000;
    $display("Finished linetest simulation");
    $finish;
  end
endmodule
