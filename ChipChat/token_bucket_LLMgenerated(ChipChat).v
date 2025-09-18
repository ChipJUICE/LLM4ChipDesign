
module token_bucket #(
    parameter DEN = 16,
    parameter RATE_NUM = 3,
    parameter BURST_MAX = 8,
    parameter TOKEN_COST = DEN
) (
    input wire clk,
    input wire rst_n,
    input wire req_i,
    output wire grant_o,
    output wire ready_o
);

    localparam [31:0] MAX_TOKENS = BURST_MAX * DEN;

    reg [31:0] tokens;
    reg grant_o_reg;

    assign grant_o = grant_o_reg;
    assign ready_o = (tokens >= TOKEN_COST);

    wire [31:0] added_tokens;
    assign added_tokens = (tokens + RATE_NUM > MAX_TOKENS) ? MAX_TOKENS : (tokens + RATE_NUM);

    always @(posedge clk) begin
        if (!rst_n) begin
            tokens <= MAX_TOKENS;
            grant_o_reg <= 1'b0;
        end else begin
            grant_o_reg <= 1'b0;
            if (req_i && (added_tokens >= TOKEN_COST)) begin
                grant_o_reg <= 1'b1;
                tokens <= added_tokens - TOKEN_COST;
            end else begin
                tokens <= added_tokens;
            end
        end
    end

endmodule
