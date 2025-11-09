//======================================================================
// Testbench : tb_speechfifo.v
// Description : Functional + Trojan test for speechfifo module
//======================================================================
`timescale 1ns/1ps

module tb_speechfifo;
  reg         i_clk = 0;
  reg [30:0]  i_setup = 31'd0;
  wire        o_uart_tx;

  speechfifo dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .o_uart_tx(o_uart_tx)
  );

  always #50 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_speechfifo.vcd");
    $dumpvars(0, tb_speechfifo);
    $display("=== Starting speechfifo simulation ===");
    #(20000);
    $display("UART TX = %b at time %0t", o_uart_tx, $time);
    $display("=== Finished speechfifo simulation ===");
    $finish;
  end
endmodule
