`timescale 1ns/1ps
module tb_aes_decipher_block;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n;

  reg         next;
  reg         keylen;
  wire  [3:0] round;
  wire [127:0] round_key;
  reg  [127:0] block;
  wire [127:0] new_block;
  wire         ready;

  reg  [255:0] key;
  wire         km_ready;
  wire [31:0]  dummy_sboxw, dummy_new_sboxw;

  integer i, cycles, cnt, ok;

  aes_key_mem keymem (
    .clk(clk), .reset_n(reset_n),
    .key(key), .keylen(keylen), .init(1'b0),
    .round(round), .round_key(round_key),
    .ready(km_ready),
    .sboxw(dummy_sboxw), .new_sboxw(dummy_new_sboxw)
  );

  aes_decipher_block dut (
    .clk(clk), .reset_n(reset_n),
    .next(next), .keylen(keylen),
    .round(round), .round_key(round_key),
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
    $display("=== tb_aes_decipher_block (Trojan DoS test) ===");
    reset_n = 0; next = 0; keylen = 1'b0;
    key = {128'h0f1571c947d9e8590cb7add6af7f6798, 128'h0};
    block = 128'h00112233445566778899aabbccddeeff;

    repeat (10) @(posedge clk); reset_n = 1; repeat (5) @(posedge clk);

    cnt = 0;
    for (i = 0; i < 900; i = i + 1) begin
      block = block + 128'h1111;

      wait_ready_with_timeout(ok, 2000);
      if (!ok) begin
        $display("[%0t] Decipher NOT READY at count=%0d", $time, cnt);
        i = 900;
      end else begin
        next = 1; @(posedge clk); next = 0;

        cycles = 0; while (ready && cycles < 100)   begin @(posedge clk); cycles = cycles + 1; end
        cycles = 0; while (!ready && cycles < 20000) begin @(posedge clk); cycles = cycles + 1; end
        if (!ready) begin
          $display("[%0t] Decipher HUNG at count=%0d", $time, cnt);
          i = 900;
        end else begin
          cnt = cnt + 1;
          if (cnt == 862) $display("Reached 862 decipher ops @ %0t", $time);
        end
      end
      @(posedge clk);
    end

    $display("Final decipher count=%0d", cnt);
    $finish;
  end
endmodule
