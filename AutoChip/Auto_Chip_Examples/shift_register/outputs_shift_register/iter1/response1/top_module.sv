module top_module(
    input wire clk,
    input wire reset_n,
    input wire data_in,
    input wire shift_enable,
    output reg [7:0] data_out
);

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        data_out <= 8'b0;
    end else if (shift_enable) begin
        data_out <= {data_out[6:0], data_in};
    end
end

always @(posedge clk) begin
    if (reset_n) begin
        // Ensure no latches are inferred
        data_out <= data_out; // Hold current value
    end
end

endmodule
