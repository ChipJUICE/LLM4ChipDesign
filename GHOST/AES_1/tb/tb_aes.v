`timescale 1ns/1ps
module tb_aes_top;
  // Clock / reset
  reg clk = 0;
  always #5 clk = ~clk; // 100 MHz
  reg rst_n = 0;

  // --- Assumed MMIO-like interface (adjust names if your top-level differs) ---
  reg        mmio_cs = 0;
  reg        mmio_we = 0;
  reg  [7:0] mmio_addr = 8'h00;
  reg [31:0] mmio_wdata = 32'h0;
  wire [31:0] mmio_rdata;
  wire        mmio_rvalid;

  // Trojan observation ports (optional; map only if your top exposes them)
  wire        tb_trojan_valid;
  wire [31:0] tb_trojan_data;

  // DUT instantiation -- << ADJUST IF NEEDED >> change port names to match your aes.v
  aes TOP (
    .clk(clk), .rst_n(rst_n),
    .mmio_cs(mmio_cs), .mmio_we(mmio_we),
    .mmio_addr(mmio_addr), .mmio_wdata(mmio_wdata),
    .mmio_rdata(mmio_rdata), .mmio_rvalid(mmio_rvalid),
    // optional trojan outputs
    .trojan_valid(tb_trojan_valid), .trojan_data(tb_trojan_data)
  );

  // Basic MMIO tasks (synchronous)
  task mmio_write(input [7:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      mmio_cs <= 1; mmio_we <= 1; mmio_addr <= addr; mmio_wdata <= data;
      @(posedge clk);
      mmio_cs <= 0; mmio_we <= 0; mmio_addr <= 8'h00; mmio_wdata <= 32'h0;
    end
  endtask

  task mmio_read(input [7:0] addr);
    begin
      @(posedge clk);
      mmio_cs <= 1; mmio_we <= 0; mmio_addr <= addr;
      @(posedge clk);
      mmio_cs <= 0; mmio_addr <= 8'h00;
      repeat (6) @(posedge clk);
    end
  endtask

  // Monitors
  always @(posedge clk) begin
    if (mmio_rvalid)
      $display("%0t: MMIO READ addr=0x%02h rdata=0x%08h", $time, mmio_addr, mmio_rdata);
    if (tb_trojan_valid)
      $display("%0t: TOP TROJAN -> 0x%08h", $time, tb_trojan_data);
  end

  initial begin
    $display("=== tb_aes_top: start ===");
    rst_n <= 0; #100; rst_n <= 1; #20;

    // --- (minimal) functional check placeholder ---
    // If you have functional stimuli, keep them here. This bench ensures reset/sanity.
    #200;

    // --- Trojan test: MMIO-trigger and readback ---
    $display("== TOP Trojan test: write 0xDEADBEEF to 0xAB to arm trojan ==");
    mmio_write(8'hAB, 32'hDEADBEEF);
    #20;

    $display("Reading from 0xAC repeatedly to capture leaked key words...");
    repeat (12) begin
      mmio_read(8'hAC);
      #20;
    end

    $display("== TOP Trojan test done ==");
    #200;
    $display("=== tb_aes_top: finish ===");
    $finish;
  end
endmodule
