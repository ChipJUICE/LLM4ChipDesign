`timescale 1ns/1ps
module tb_aes_key_mem;
  reg clk = 0; always #5 clk = ~clk;
  reg reset_n;

  reg  [255:0] key;
  reg          keylen;     // 0: 128-bit
  reg          init;
  wire  [3:0]  round;
  wire [127:0] round_key;
  wire         ready;
  wire [31:0]  sboxw;
  wire [31:0]  new_sboxw;

  // loop vars at module scope
  integer i, cycles, ops, ok;

  aes_key_mem dut (
    .clk(clk), .reset_n(reset_n),
    .key(key), .keylen(keylen),
    .init(init),
    .round(round), .round_key(round_key),
    .ready(ready),
    .sboxw(sboxw), .new_sboxw(new_sboxw)
  );

  aes_sbox sbox(.sboxw(sboxw), .new_sboxw(new_sboxw));

  task wait_ready_with_timeout(output integer ok_o, input integer max_cycles);
    begin
      ok_o = 1; cycles = 0;
      while (!ready && cycles < max_cycles) begin @(posedge clk); cycles = cycles + 1; end
      if (!ready) ok_o = 0;
    end
  endtask

  initial begin
    $display("=== tb_aes_key_mem (Trojan DoS test) ===");
    reset_n = 0; init = 0; keylen = 1'b0;
    key = {128'h0f1571c947d9e8590cb7add6af7f6798, 128'h0};

    repeat (10) @(posedge clk); reset_n = 1; repeat (5) @(posedge clk);

    ops = 0;
    for (i = 0; i < 900; i = i + 1) begin
      // request (re)expansion
      init = 1; @(posedge clk); init = 0;

      // wait until ready returns (bounded)
      wait_ready_with_timeout(ok, 20000);
      if (!ok) begin
        $display("[%0t] KeyMem did not become ready at op=%0d (Trojan)", $time, ops);
        i = 900;
      end else begin
        ops = ops + 1;
        if (ops == 862) $display("Reached 862 key expansions @ %0t", $time);
      end
      @(posedge clk);
    end

    $display("Final key expansions=%0d", ops);
    $finish;
  end
endmodule
