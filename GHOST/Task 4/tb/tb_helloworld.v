//======================================================================
// Testbench : tb_helloworld.v
// Description : Basic functional + Trojan check for helloworld
//======================================================================
`timescale 1ns/1ps

module tb_helloworld;
  reg         i_clk = 0;
  reg [30:0]  i_setup = 31'd0;
  wire        o_uart_tx;

  helloworld dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .o_uart_tx(o_uart_tx)
  );

  always #50 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_helloworld.vcd");
    $dumpvars(0, tb_helloworld);
    $display("=== Starting helloworld simulation ===");
    #(10000);
    $display("UART TX = %b at time %0t", o_uart_tx, $time);
    $display("=== Finished helloworld simulation ===");
    $finish;
  end
endmodule
