`timescale 1ns/1ps
module tb_speechfifo;
  reg i_clk = 0;
  reg [30:0] i_setup = 31'd868;
  wire o_uart_tx;

  // speechfifo in your copy has ports (i_clk, i_setup, o_uart_tx)
  speechfifo dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .o_uart_tx(o_uart_tx)
  );

  always #5 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_speechfifo.vcd");
    $dumpvars(0, tb_speechfifo);

    #20000;
    $display("Finished speechfifo simulation");
    $finish;
  end
endmodule
