`timescale 1ns/1ps
module tb_aes_encipher_block;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n;

  // Encipher I/F
  reg         next;
  reg         keylen;          // 0=128
  wire  [3:0] round;
  wire [127:0] round_key;
  wire [31:0]  sboxw;
  wire [31:0]  new_sboxw;
  reg  [127:0] block;
  wire [127:0] new_block;
  wire         ready;

  // Support blocks
  reg  [255:0] key;
  wire         km_ready;
  wire [31:0]  dummy_sboxw, dummy_new_sboxw;

  // Declare loop vars at module scope
  integer i, cycles, cnt, ok;

  aes_key_mem keymem (
    .clk(clk), .reset_n(reset_n),
    .key(key), .keylen(keylen), .init(1'b0),
    .round(round), .round_key(round_key),
    .ready(km_ready),
    .sboxw(dummy_sboxw), .new_sboxw(dummy_new_sboxw)
  );

  aes_sbox sbox (.sboxw(sboxw), .new_sboxw(new_sboxw));

  aes_encipher_block dut (
    .clk(clk), .reset_n(reset_n),
    .next(next), .keylen(keylen),
    .round(round), .round_key(round_key),
    .sboxw(sboxw), .new_sboxw(new_sboxw),
    .block(block), .new_block(new_block),
    .ready(ready)
  );

  task wait_ready_with_timeout(output integer ok_o, input integer max_cycles);
    begin
      ok_o = 1; cycles = 0;
      while (!ready && cycles < max_cycles) begin @(posedge clk); cycles = cycles + 1; end
      if (!ready) ok_o = 0;
    end
  endtask

  initial begin
    $display("=== tb_aes_encipher_block (Trojan DoS test) ===");
    reset_n = 0; next = 0; keylen = 1'b0;
    key = {128'h00112233445566778899aabbccddeeff, 128'h0};
    block = 128'h0123456789abcdef0123456789abcdef;

    repeat (10) @(posedge clk); reset_n = 1; repeat (5) @(posedge clk);

    cnt = 0;
    for (i = 0; i < 900; i = i + 1) begin
      block = block + 128'h1;

      wait_ready_with_timeout(ok, 2000);
      if (!ok) begin
        $display("[%0t] Encipher NOT READY at count=%0d (Trojan?)", $time, cnt);
        i = 900; // stop
      end else begin
        next = 1; @(posedge clk); next = 0;

        // wait for ready to cycle back (bounded)
        cycles = 0; while (ready && cycles < 100)   begin @(posedge clk); cycles = cycles + 1; end
        cycles = 0; while (!ready && cycles < 20000) begin @(posedge clk); cycles = cycles + 1; end
        if (!ready) begin
          $display("[%0t] Encipher HUNG at count=%0d", $time, cnt);
          i = 900;
        end else begin
          cnt = cnt + 1;
          if (cnt == 862) $display("Reached 862 encipher ops @ %0t", $time);
        end
      end
      @(posedge clk);
    end

    $display("Final encipher count=%0d", cnt);
    $finish;
  end
endmodule
