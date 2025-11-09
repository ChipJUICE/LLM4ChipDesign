`timescale 1ns/1ps
module tb_helloworld;
  reg i_clk = 0;
  reg [30:0] i_setup = 31'd868;
  wire o_uart_tx;
  // Connect TX -> RX loop if the module reads RX; many helloworld variants include i_uart_rx.
  // To be safe, we try to connect an rx wire only if the DUT declares it. The file you provided does include i_uart_rx,
  // so we connect it here.
  wire i_uart_rx = o_uart_tx;

  helloworld dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx)
  );

  always #5 i_clk = ~i_clk;

  initial begin
    $dumpfile("tb_helloworld.vcd");
    $dumpvars(0, tb_helloworld);

    #20000;
    $display("Finished helloworld simulation");
    $finish;
  end
endmodule
