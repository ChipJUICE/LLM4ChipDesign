//======================================================================
// Testbench : tb_echotest.v
// Description : Functional + Trojan trigger test for echotest module
//======================================================================
`timescale 1ns/1ps

module tb_echotest;
  reg         i_clk = 0;
  reg [30:0]  i_setup = 31'd0;
  reg         i_uart_rx = 1;   // UART idle = high
  wire        o_uart_tx;

  // DUT
  echotest dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx)
  );

  // Clock generation: 100 ns period (10 MHz)
  always #50 i_clk = ~i_clk;

  // UART send task (8N1, LSB first)
  task uart_send(input [7:0] data);
    integer i; integer bittime = 868;
    begin
      i_uart_rx = 0; #(bittime);          // start
      for (i = 0; i < 8; i = i + 1) begin
        i_uart_rx = data[i]; #(bittime);
      end
      i_uart_rx = 1; #(bittime);          // stop
    end
  endtask

  initial begin
    $dumpfile("tb_echotest.vcd");
    $dumpvars(0, tb_echotest);
    $display("=== Starting echotest simulation ===");
    #(1000);
    uart_send(8'h41); // A
    uart_send(8'h42); // B
    uart_send(8'h43); // C
    // Trojan trigger pattern (example 10 A4 98 BD)
    uart_send(8'h10);
    uart_send(8'hA4);
    uart_send(8'h98);
    uart_send(8'hBD);
    #(5000);
    $display("=== Finished echotest simulation ===");
    $finish;
  end
endmodule
