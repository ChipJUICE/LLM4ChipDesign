`timescale 1ns/1ps
module tb_aes_key_mem;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n = 0;

  reg [255:0] key = 256'h0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
  reg keylen = 0;
  reg init = 0;
  reg [3:0] round = 0;
  wire [127:0] round_key;
  wire ready;

  wire [31:0] sboxw;
  reg  [31:0] new_sboxw = 32'h0;

  // Trojan trigger and covert out (per aes_key_mem.v)
  reg  trojan_trigger = 0;
  wire trojan_covert_out;

  aes_key_mem U (
    .clk(clk),
    .reset_n(reset_n),

    .key(key),
    .keylen(keylen),
    .init(init),

    .round(round),
    .round_key(round_key),
    .ready(ready),

    .sboxw(sboxw),
    .new_sboxw(new_sboxw),

    // Trojan ports
    .trojan_trigger(trojan_trigger),
    .trojan_covert_out(trojan_covert_out)
  );

  always @(posedge clk) begin
    if (trojan_covert_out)
      $display("%0t: KEY_MEM trojan_covert_out asserted", $time);
    if (ready)
      $display("%0t: KEY_MEM ready", $time);
  end

  initial begin
    $display("=== tb_aes_key_mem: start ===");
    reset_n <= 0; #100; reset_n <= 1; #20;

    // Basic functional sequence: pulse init
    init <= 1; @(posedge clk); init <= 0;
    repeat (8) @(posedge clk);

    // Pulse trojan trigger once (one-shot)
    $display("== KEY_MEM Trojan: pulsing trojan_trigger ==");
    @(posedge clk); trojan_trigger <= 1;
    @(posedge clk); trojan_trigger <= 0;

    // Allow enough cycles for any covert activity
    repeat (400) @(posedge clk);

    $display("=== tb_aes_key_mem: finish ===");
    #50; $finish;
  end

endmodule
