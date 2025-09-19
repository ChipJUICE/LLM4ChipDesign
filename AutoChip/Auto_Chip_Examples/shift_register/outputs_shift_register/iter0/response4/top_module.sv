module top_module(
    input wire clk,
    input wire reset_n,
    input wire data_in,
    input wire shift_enable,
    output reg [7:0] data_out
);

    initial begin
        data_out = 8'h0A; // Preload data_out with 8'h0A
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_out <= 8'b0; // Clear data_out to all zeros on reset
        end else begin
            data_out <= {1'b0, data_out[7:1]}; // Logical right shift with zero fill
        end
    end

endmodule
