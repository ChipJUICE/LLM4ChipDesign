/*
You are generating synthesizable Verilog-2001.
Output ONLY one code block with NO markdown fences, NO prose, and nothing outside the module.

Write a single Verilog-2001 module with the following exact header:

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

STRICT CODING RULES (to avoid Icarus warnings and ensure TB matching):
- Pure Verilog-2001 only. Do NOT use any SystemVerilog features (no 'logic', no 'always_ff', no 'typedef', etc.).
- Do NOT use inline initializations in declarations anywhere (e.g., 'reg x = 0;' is forbidden).
- Do NOT declare variables inside procedural blocks. Declare all regs/wires at module scope.
- Use a single sequential block: 'always @(posedge clk)' with nonblocking (<=) assignments only.
- No 'initial' blocks, no delays (#), no $display/$finish, no latches.
- Treat all token-related math as 32-bit wide signals.

FUNCTIONAL REQUIREMENTS (must match the reference testbench semantics exactly):
1) State:
   - Declare 'reg [31:0] tokens;' to hold the token count.
   - Declare 'reg grant_q;' to register the 1-cycle grant pulse.
   - Declare 'localparam [31:0] MAX_TOKENS = BURST_MAX * DEN;'.

2) Combinational intermediates (module-scope wires with continuous assigns, NOT inside always):
   - 'wire [31:0] tokens_added;'
   - 'wire [31:0] tokens_sat;'
   - 'assign tokens_added = tokens + RATE_NUM;'
   - 'assign tokens_sat   = (tokens_added > MAX_TOKENS) ? MAX_TOKENS : tokens_added;'

3) Outputs (must use POST-ADD value):
   - 'assign ready_o = (tokens_sat >= TOKEN_COST);'  // purely combinational
   - 'assign grant_o = grant_q;'                      // registered 1-cycle pulse

4) Reset behavior (bucket starts FULL):
   - In 'always @(posedge clk)': if (!rst_n) begin
       tokens  <= MAX_TOKENS;
       grant_q <= 1'b0;
     end else begin
       // see update rules below
     end

5) Per-cycle update (POST-ADD semantics):
   - Base all decisions on 'tokens_sat' (the POST-ADD saturated value), NOT on 'tokens'.
   - If (req_i && (tokens_sat >= TOKEN_COST)) begin
       grant_q <= 1'b1;              // assert grant for exactly this cycle
       tokens  <= tokens_sat - TOKEN_COST;  // consume after add+saturate
     end else begin
       grant_q <= 1'b0;              // MUST clear every non-grant cycle
       tokens  <= tokens_sat;        // refill/saturate without consuming
     end

Provide the complete module implementation beginning with the header above and ending with 'endmodule'. 
Return ONLY the single code block of the module, nothing else.
*/