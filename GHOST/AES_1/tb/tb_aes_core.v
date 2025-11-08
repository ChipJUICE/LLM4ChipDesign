`timescale 1ns/1ps
module tb_aes_core;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n = 0;

  // control signals
  reg encdec = 0;
  reg init   = 0;
  reg next   = 0;
  wire ready;

  // key inputs (256-bit)
  reg [255:0] key = 256'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
  reg keylen = 1'b0; // module expects 1 bit

  // block/result
  reg  [127:0] block;
  wire [127:0] result;
  wire         result_valid;

  // Trojan outputs (per aes_core.v)
  wire trojan_leak;       // 1-bit
  wire [7:0] trojan_data; // 8-bit covert data

  // Instantiate DUT (port names match aes_core.v)
  aes_core DUT (
    .clk(clk),
    .reset_n(reset_n),

    .encdec(encdec),
    .init(init),
    .next(next),
    .ready(ready),

    .key(key),
    .keylen(keylen),

    .block(block),
    .result(result),
    .result_valid(result_valid),

    // Trojan (covert) outputs
    .trojan_leak(trojan_leak),
    .trojan_data(trojan_data)
  );

  // Monitor trojan outputs and some basic progress info
  always @(posedge clk) begin
    if (trojan_leak)
      $display("%0t: AES_CORE TROJAN_LEAK asserted, trojan_data=0x%02h", $time, trojan_data);
    if (result_valid)
      $display("%0t: AES_CORE RESULT_VALID, result[127:120]=0x%02h", $time, result[127:120]);
  end

  initial begin
    $display("=== tb_aes_core: start ===");
    reset_n <= 0; #100; reset_n <= 1; #20;

    // Provide a dummy block for a short functional run (keeps original function intact)
    block <= 128'h00112233445566778899aabbccddeeff;
    init  <= 1; @(posedge clk); init <= 0;

    // pulse next a few times to simulate encrypt cycles (functional)
    repeat (10) begin
      @(posedge clk); next <= 1;
      @(posedge clk); next <= 0;
    end

    // --- Trojan trigger: send the 4-cycle parity pattern (aim for 1,0,1,1) ---
    $display("== AES_CORE Trojan trigger sequence ==");
    // cycle 1 -> parity = 1
    init <= 1; next <= 0; encdec <= 0; keylen <= 1'b1; @(posedge clk);
    // cycle 2 -> parity = 0
    init <= 0; next <= 0; encdec <= 0; keylen <= 1'b0; @(posedge clk);
    // cycle 3 -> parity = 1
    init <= 1; next <= 0; encdec <= 0; keylen <= 1'b0; @(posedge clk);
    // cycle 4 -> parity = 1
    init <= 0; next <= 1; encdec <= 0; keylen <= 1'b0; @(posedge clk);

    // Allow time for any covert stream to appear
    repeat (120) @(posedge clk);

    $display("=== tb_aes_core: finish ===");
    #50;
    $finish;
  end

endmodule
