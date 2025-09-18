// Token Bucket implementation in Verilog
// This module controls requests using a rate-based token allocation scheme.
// Parameters allow customization of rate, burst size, and cost per request.

module token_bucket #(
    parameter DEN = 16,              // Denominator for scaling tokens (granularity)
    parameter RATE_NUM = 3,          // Number of tokens added per clock cycle
    parameter BURST_MAX = 8,         // Maximum burst size (how many requests can be granted consecutively)
    parameter TOKEN_COST = DEN       // Tokens required per request (default: DEN)
) (
    input wire clk,                  // Clock input
    input wire rst_n,                // Active-low reset
    input wire req_i,                // Incoming request signal
    output wire grant_o,             // Grant signal: high when request is allowed
    output wire ready_o              // Ready signal: high when enough tokens are available
);

    // Maximum tokens that can accumulate (burst capacity scaled by denominator)
    localparam [31:0] MAX_TOKENS = BURST_MAX * DEN;

    // Current token count
    reg [31:0] tokens;

    // Register to hold grant output
    reg grant_o_reg;

    // Connect registered grant signal to output
    assign grant_o = grant_o_reg;

    // Ready when enough tokens are available to pay for one request
    assign ready_o = (tokens >= TOKEN_COST);

    // Compute tokens after adding RATE_NUM, capped at MAX_TOKENS
    wire [31:0] added_tokens;
    assign added_tokens = (tokens + RATE_NUM > MAX_TOKENS) 
                          ? MAX_TOKENS 
                          : (tokens + RATE_NUM);

    // Sequential logic: update tokens and grant signal
    always @(posedge clk) begin
        if (!rst_n) begin
            // On reset: fill bucket to max and clear grant
            tokens <= MAX_TOKENS;
            grant_o_reg <= 1'b0;
        end else begin
            // Default: no grant this cycle
            grant_o_reg <= 1'b0;

            // If request comes in and enough tokens exist:
            if (req_i && (added_tokens >= TOKEN_COST)) begin
                // Approve request (grant high for 1 cycle)
                grant_o_reg <= 1'b1;
                // Deduct token cost from bucket
                tokens <= added_tokens - TOKEN_COST;
            end else begin
                // Otherwise, just accumulate tokens (up to MAX_TOKENS)
                tokens <= added_tokens;
            end
        end
    end

endmodule
