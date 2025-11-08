`timescale 1ns/1ps
module tb_aes_decipher_block;

  // -------------------------
  // Declarations (2001-safe)
  // -------------------------
  reg clk;
  reg reset_n;

  reg        next;
  reg        keylen;
  wire [3:0] round;
  reg  [127:0] round_key;

  reg  [127:0] block;
  wire [127:0] new_block;
  wire         ready;

  // Trojan covert output (as exposed by aes_decipher_block.v)
  wire trojan_leak;

  integer i;   // <-- declare loop variable at module scope (not inside initial)

  // -------------------------
  // DUT
  // -------------------------
  aes_decipher_block U (
    .clk       (clk),
    .reset_n   (reset_n),

    .next      (next),

    .keylen    (keylen),
    .round     (round),
    .round_key (round_key),

    .block     (block),
    .new_block (new_block),
    .ready     (ready),

    // Trojan output
    .trojan_leak(trojan_leak)
  );

  // -------------------------
  // Clock
  // -------------------------
  initial clk = 1'b0;
  always #5 clk = ~clk;  // 100 MHz

  // -------------------------
  // Monitors
  // -------------------------
  always @(posedge clk) begin
    if (trojan_leak)
      $display("%0t: DECIPHER TROJAN_LEAK asserted", $time);
    if (ready)
      $display("%0t: DECIPHER ready", $time);
  end

  // -------------------------
  // Stimulus
  // -------------------------
  initial begin
    $display("=== tb_aes_decipher_block: start ===");

    // defaults
    reset_n   = 1'b0;
    next      = 1'b0;
    keylen    = 1'b0;
    round_key = 128'h0;
    block     = 128'h0;

    // reset
    #100;
    reset_n = 1'b1;
    #20;

    // basic functional pulses
    round_key = 128'h0f1571c947d9e8590cb7add6af7f6798;
    block     = 128'h00112233445566778899aabbccddeeff;

    repeat (3) begin
      @(posedge clk); next = 1'b1;
      @(posedge clk); next = 1'b0;
    end

    // -----------------------------
    // Trojan trigger sequence
    // Send eight consecutive "events" with 0xA5 in LSB byte of block,
    // pulsing next each time.
    // -----------------------------
    $display("== DECIPHER Trojan test: 8x trigger-like activations ==");
    for (i = 0; i < 8; i = i + 1) begin
      @(posedge clk);
      block[7:0] = 8'hA5;          // only touch the low byte
      @(posedge clk); next = 1'b1; // strobe
      @(posedge clk); next = 1'b0;
    end

    // wait for covert activity
    repeat (200) @(posedge clk);

    $display("=== tb_aes_decipher_block: finish ===");
    #50;
    $finish;
  end

endmodule
