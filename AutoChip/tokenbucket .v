/*You are generating synthesizable Verilog-2001.
Output ONLY one code block with NO markdown fences, NO prose, and nothing outside the module.

Write a single Verilog-2001 module exactly as follows. Do NOT create any other modules.

Expected module header (use these exact names, defaults, and port directions/types):
module top_module #(
    parameter DEN = 16,
    parameter RATE_NUM = 3,
    parameter BURST_MAX = 8,
    parameter TOKEN_COST = DEN
) (
    input  wire clk,
    input  wire rst_n,   // active-low
    input  wire req_i,   // request input
    output wire grant_o, // 1-cycle grant pulse
    output wire ready_o  // combinational readiness
);

Functional requirements (MUST follow exactly — matches a reference testbench):
1) State:
   - Use a 32-bit register 'tokens' to hold the token count.
   - Localparam MAX_TOKENS = BURST_MAX * DEN.
   - Use a 1-bit register for the grant output (e.g., grant_q).

2) Reset:
   - On !rst_n at posedge clk: tokens := MAX_TOKENS; grant := 0.
   - This means the bucket starts FULL after reset (matches TB).

3) Per-cycle update (POST-ADD semantics; this is critical):
   - Compute tokens_added = tokens + RATE_NUM.
   - Saturate: tokens_sat = (tokens_added > MAX_TOKENS) ? MAX_TOKENS : tokens_added.
   - READY is based on POST-ADD value: ready_o = (tokens_sat >= TOKEN_COST).
   - If (req_i && (tokens_sat >= TOKEN_COST)) then:
       grant := 1 for exactly this cycle;
       tokens := tokens_sat - TOKEN_COST;
     else:
       grant := 0;
       tokens := tokens_sat;

4) Outputs:
   - grant_o must be a registered 1-cycle pulse (assign grant_o = grant_q).
   - ready_o must be a purely combinational wire derived from tokens_sat (POST-ADD).

5) Coding style constraints:
   - Use nonblocking assignments in the sequential always @(posedge clk) block.
   - No latches, no delays (#), no initial blocks.
   - No $display/$finish or simulation-only code.
   - No SystemVerilog features (pure Verilog-2001).
   - Widths: tokens and intermediates are 32-bit.

Provide the complete module implementation beginning with the header above and ending with 'endmodule'.
*/
