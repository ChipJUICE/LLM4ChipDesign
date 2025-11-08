`timescale 1ns/1ps
module tb_aes;
  // clock
  reg clk = 0;
  always #5 clk = ~clk;

  // reset & IO (rename ports in instantiation if yours differs)
  reg         rst_n;
  reg         init;
  reg         next;
  reg  [127:0] key;
  reg  [127:0] plaintext;
  wire [127:0] ciphertext;
  wire        ready;
  wire        done;

  // DUT (rename ports to match your top-level if needed)
  aes uut (
    .clk       (clk),
    .rst_n     (rst_n),
    .init      (init),
    .next      (next),
    .key       (key),
    .block_in  (plaintext),
    .block_out (ciphertext),
    .ready     (ready),
    .done      (done)
  );

  integer enc_count;
  integer i;
  reg stop_sim;
  integer timeout;

  // one encryption attempt with timeouts; returns 1 if success, 0 if fail
  function automatic integer do_encrypt;
    integer t1;
    begin
      do_encrypt = 0;

      // wait for ready (with timeout)
      t1 = 0;
      while (!ready && t1 < 2000) begin @(posedge clk); t1 = t1 + 1; end
      if (!ready) begin
        $display("[%0t] NOT READY (Trojan likely engaged) at enc_count=%0d", $time, enc_count);
        disable_wait: do_encrypt = 0; // fall through
      end else begin
        // pulse next
        next = 1; @(posedge clk); next = 0;

        // wait for done
        t1 = 0;
        while (!done && t1 < 20000) begin @(posedge clk); t1 = t1 + 1; end
        if (!done) begin
          $display("[%0t] HUNG (no DONE) at enc_count=%0d", $time, enc_count);
          do_encrypt = 0;
        end else begin
          do_encrypt = 1;
        end
      end
    end
  endfunction

  initial begin
    $display("=== tb_aes start ===");
    clk = 0;
    rst_n = 0; init = 0; next = 0; stop_sim = 0;
    key = 128'h00112233445566778899aabbccddeeff;
    plaintext = 128'h00112233445566778899aabbccddeeff;
    enc_count = 0;

    #100; rst_n = 1; #50;

    // Optional init pulse if your core needs it
    init = 1; @(posedge clk); init = 0; @(posedge clk);

    for (i = 0; i < 900 && !stop_sim; i = i + 1) begin
      if (do_encrypt()) begin
        enc_count = enc_count + 1;
        if (enc_count % 100 == 0) $display("[%0t] Completed: %0d", $time, enc_count);
      end else begin
        stop_sim = 1; // stop attempting more once we see refusal/hang
      end
      @(posedge clk);
    end

    $display("Loop ended; successful enc_count=%0d", enc_count);

    // Quick probe for sticky DoS after threshold
    if (enc_count >= 862) begin
      $display("Probing sticky halt after threshold...");
      if (do_encrypt() == 0)
        $display("Trojan detected: no further progress after %0d encryptions.", enc_count);
      else
        $display("No Trojan effect observed; encryption still succeeds post-threshold.");
    end

    $display("=== tb_aes done ===");
    $finish;
  end
endmodule
