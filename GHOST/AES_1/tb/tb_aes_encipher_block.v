`timescale 1ns/1ps
module tb_aes_encipher_block;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n = 0;

  reg next = 0;
  reg keylen = 0;
  wire [3:0] round;
  reg  [127:0] round_key = 128'h0;
  wire [31:0] sboxw;
  reg  [31:0] new_sboxw = 32'h0;

  reg  [127:0] block;
  wire [127:0] new_block;
  wire ready;

  // Trojan ports (match aes_encipher_block.v)
  reg  [7:0]  trojan_trigger = 8'h00; // input
  wire        trojan_valid;           // output
  wire [7:0]  trojan_data;            // 8-bit output

  aes_encipher_block U (
    .clk(clk),
    .reset_n(reset_n),

    .next(next),

    .keylen(keylen),
    .round(round),
    .round_key(round_key),

    .sboxw(sboxw),
    .new_sboxw(new_sboxw),

    .block(block),
    .new_block(new_block),
    .ready(ready),

    // Trojan ports
    .trojan_trigger(trojan_trigger),
    .trojan_valid(trojan_valid),
    .trojan_data(trojan_data)
  );

  always @(posedge clk) begin
    if (trojan_valid)
      $display("%0t: ENCIPHER TROJAN_VALID -> trojan_data=0x%02h", $time, trojan_data);
    if (ready)
      $display("%0t: ENCIPHER ready asserted", $time);
  end

  initial begin
    $display("=== tb_aes_encipher_block: start ===");
    reset_n <= 0; #100; reset_n <= 1; #20;

    // basic functional stimulus
    round_key <= 128'h0f1571c947d9e8590cb7add6af7f6798;
    block <= 128'h00112233445566778899aabbccddeeff;
    next <= 1; @(posedge clk); next <= 0;
    repeat (8) @(posedge clk);

    // Trigger Trojan: pulse trojan_trigger = 0xA5
    $display("== ENCIPHER Trojan test: pulsing trojan_trigger = 0xA5 ==");
    @(posedge clk); trojan_trigger <= 8'hA5;
    @(posedge clk); trojan_trigger <= 8'h00;

    // Allow time for leak to appear
    repeat (80) @(posedge clk);

    $display("=== tb_aes_encipher_block: finish ===");
    #50; $finish;
  end

endmodule
