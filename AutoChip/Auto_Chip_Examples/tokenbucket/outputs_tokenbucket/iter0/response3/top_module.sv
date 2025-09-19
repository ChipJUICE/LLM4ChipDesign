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

    reg [31:0] tokens;
    reg grant_q;
    localparam [31:0] MAX_TOKENS = BURST_MAX * DEN;

    wire [31:0] tokens_added;
    wire [31:0] tokens_sat;
    assign tokens_added = tokens + RATE_NUM;
    assign tokens_sat   = (tokens_added > MAX_TOKENS) ? MAX_TOKENS : tokens_added;

    assign ready_o = (tokens_sat >= TOKEN_COST);
    assign grant_o = grant_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            tokens  <= MAX_TOKENS;
            grant_q <= 1'b0;
        end else begin
            if (req_i && (tokens_sat >= TOKEN_COST)) begin
                grant_q <= 1'b1;
                tokens  <= tokens_sat - TOKEN_COST;
            end else begin
                grant_q <= 1'b0;
                tokens  <= tokens_sat;
            end
        end
    end

endmodule
