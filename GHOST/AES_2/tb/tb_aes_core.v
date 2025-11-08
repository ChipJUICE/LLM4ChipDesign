`timescale 1ns/1ps
module tb_aes_core;
  // Clock
  reg clk = 0;
  always #5 clk = ~clk;

  // DUT I/O (Secworks naming)
  reg         reset_n;
  reg         encdec;       // 1 = enc, 0 = dec
  reg         init;
  reg         next;
  wire        ready;

  reg  [255:0] key;
  reg          keylen;      // 0: 128-bit, 1: 256-bit
  reg  [127:0] block;
  wire [127:0] result;
  wire         result_valid;

  // Loop/state vars (declare at module scope!)
  integer i, cycles, enc_count, ok;
  reg stop_sim;

  // DUT
  aes_core dut (
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
    .result_valid(result_valid)
  );

  // Helpers
  task wait_ready_with_timeout(output integer ok_o, input integer max_cycles);
    begin
      ok_o = 1; cycles = 0;
      while (!ready && cycles < max_cycles) begin @(posedge clk); cycles = cycles + 1; end
      if (!ready) ok_o = 0;
    end
  endtask

  task wait_result_with_timeout(output integer ok_o, input integer max_cycles);
    begin
      ok_o = 1; cycles = 0;
      while (!result_valid && cycles < max_cycles) begin @(posedge clk); cycles = cycles + 1; end
      if (!result_valid) ok_o = 0;
    end
  endtask

  // Test
  initial begin
    $display("=== tb_aes_core (Trojan DoS test) ===");
    reset_n = 0; encdec = 1'b1; init = 0; next = 0; stop_sim = 0;
    keylen = 1'b0;                                  // 128-bit
    key    = {128'h00112233445566778899aabbccddeeff, 128'h0};
    block  = 128'h00112233445566778899aabbccddeeff;

    repeat (10) @(posedge clk);
    reset_n = 1;
    repeat (5) @(posedge clk);

    // key expansion
    init = 1; @(posedge clk); init = 0;
    wait_ready_with_timeout(ok, 20000);
    if (!ok) begin $display("ERROR: never got ready after init"); $finish; end

    // >862 encryptions
    enc_count = 0;
    for (i = 0; i < 900 && !stop_sim; i = i + 1) begin
      block = block + 128'h1;

      wait_ready_with_timeout(ok, 2000);
      if (!ok) begin
        $display("[%0t] NOT READY before op #%0d (Trojan?)", $time, enc_count);
        stop_sim = 1;
      end else begin
        next = 1; @(posedge clk); next = 0;
        wait_result_with_timeout(ok, 20000);
        if (!ok) begin
          $display("[%0t] No result_valid for op #%0d (HANG/Trojan)", $time, enc_count);
          stop_sim = 1;
        end else begin
          enc_count = enc_count + 1;
          if (enc_count % 100 == 0) $display("Completed %0d", enc_count);
        end
      end
      @(posedge clk);
    end

    $display("Loop ended; enc_count=%0d", enc_count);

    if (enc_count >= 862) begin
      wait_ready_with_timeout(ok, 2000);
      if (ok) begin
        next = 1; @(posedge clk); next = 0;
        wait_result_with_timeout(ok, 20000);
      end
      if (!ok) $display("Trojan detected: no progress after %0d encryptions.", enc_count);
      else     $display("No Trojan visible: still progressed after %0d.", enc_count);
    end

    $display("=== tb_aes_core done ===");
    $finish;
  end
endmodule
