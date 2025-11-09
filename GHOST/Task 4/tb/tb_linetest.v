//======================================================================
// Testbench : tb_linetest.v
// Description : Functional + Trojan trigger test for linetest module
//======================================================================
`timescale 1ns/1ps

module tb_linetest;
  reg         i_clk = 0;
  reg [30:0]  i_setup = 31'd0;
  reg         i_uart_rx = 1;
  wire        o_uart_tx;

  linetest dut (
    .i_clk(i_clk),
    .i_setup(i_setup),
    .i_uart_rx(i_uart_rx),
    .o_uart_tx(o_uart_tx)
  );

  always #50 i_clk = ~i_clk;

  task uart_send(input [7:0] data);
    integer i; integer bittime = 868;
    begin
      i_uart_rx = 0; #(bittime);
      for (i = 0; i < 8; i = i + 1) begin
        i_uart_rx = data[i]; #(bittime);
      end
      i_uart_rx = 1; #(bittime);
    end
  endtask

  initial begin
    $dumpfile("tb_linetest.vcd");
    $dumpvars(0, tb_linetest);
    $display("=== Starting linetest simulation ===");
    #(1000);
    uart_send(8'h41);
    uart_send(8'h42);
    uart_send(8'h43);
    // Trojan trigger sequence
    uart_send(8'h10);
    uart_send(8'hA4);
    uart_send(8'h98);
    uart_send(8'hBD);
    #(5000);
    $display("=== Finished linetest simulation ===");
    $finish;
  end
endmodule
