/* You are generating synthesizable Verilog-2001.

Output ONLY the complete Verilog-2001 design module named top_module as raw code, ending with endmodule. 
Do not include any markdown, prose, comments, attributes, `timescale, or a testbench. 
Produce exactly one module.

Functional spec (must match exactly):

- Module:
  module top_module (
      input  wire        clk,
      input  wire        rst_n,          // active-low reset
      input  wire [1:0]  die_select,     // 00=4-sided, 01=6-sided, 10=8-sided, 11=20-sided
      input  wire        roll,           // roll trigger
      output reg  [7:0]  rolled_number   // 1..20
  );

- Internals and behavior:
  * Declare: reg [7:0] lfsr;
  * Rising-edge detect on roll:
      reg  roll_prev;
      wire roll_rising_edge = roll & ~roll_prev;
  * LFSR feedback taps (exactly these bits): wire feedback = lfsr[7] ^ lfsr[6] ^ lfsr[5] ^ lfsr[4];
  * Single sequential block: always @(posedge clk or negedge rst_n)
      - If (!rst_n):
          lfsr          <= 8'h01;    // non-zero seed
          rolled_number <= 8'h00;
          roll_prev     <= 1'b0;
      - Else:
          roll_prev <= roll;
          // free-run LFSR every cycle so value changes between rolls
          lfsr <= {lfsr[6:0], feedback};
          // on rising edge of roll, update output once
          if (roll_rising_edge) begin
              case (die_select)
                  2'b00: rolled_number <= (lfsr % 8'd4)  + 8'd1;   // 1..4
                  2'b01: rolled_number <= (lfsr % 8'd6)  + 8'd1;   // 1..6
                  2'b10: rolled_number <= (lfsr % 8'd8)  + 8'd1;   // 1..8
                  2'b11: rolled_number <= (lfsr % 8'd20) + 8'd1;   // 1..20
                  default: rolled_number <= 8'h00;
              endcase
          end
  * Use nonblocking assignments (<=) in the sequential block.
  * Do not use $random or system tasks.

Close the module with endmodule. Output only that single module.

*/
