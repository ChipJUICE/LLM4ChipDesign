`timescale 1ns/1ps

module token_bucket #(
    parameter integer DEN        = 16,
    parameter integer RATE_NUM   = 3,
    parameter integer BURST_MAX  = 8,
    parameter integer TOKEN_COST = DEN
)(
    input  wire clk,
    input  wire rst_n,      // active-low synchronous reset
    input  wire req_i,
    output reg  grant_o,
    output wire ready_o
);
    // Capacity in "token units" (scale = DEN per request)
    localparam [31:0] TOK_MAX_32 = BURST_MAX * DEN;

    // Token counter
    reg  [31:0] tokens_q;

    // --- Post-add saturated tokens this cycle ---
    wire [32:0] sum_ext     = {1'b0, tokens_q} + RATE_NUM[31:0];
    wire [32:0] tokmax_ext  = {1'b0, TOK_MAX_32};
    wire [31:0] add_sat     = (sum_ext > tokmax_ext) ? TOK_MAX_32 : sum_ext[31:0];

    // Decide grant using post-add tokens
    wire        can_grant   = (add_sat >= TOKEN_COST[31:0]);
    wire        will_grant  = req_i && can_grant;

    // Next token count after optional consume
    wire [31:0] next_tokens = will_grant ? (add_sat - TOKEN_COST[31:0]) : add_sat;

    // Ready means: could we grant a request right now?
    assign ready_o = can_grant;

    // State update
    always @(posedge clk) begin
        if (!rst_n) begin
            tokens_q <= TOK_MAX_32;  // start full for immediate burst demo
            grant_o  <= 1'b0;
        end else begin
            tokens_q <= next_tokens;
            grant_o  <= will_grant;
        end
    end

endmodule
