module top_module (
    input  wire clk,
    input  wire reset_n,
    input  wire [2:0] data,
    output wire sequence_found
);
    localparam S0 = 4'd0, S1 = 4'd1, S2 = 4'd2, S3 = 4'd3, S4 = 4'd4, S5 = 4'd5, S6 = 4'd6, S7 = 4'd7;
    reg [3:0] state, next_state, prev_state;

    always @(*) begin
        case(state)
            S0: next_state = (data == 3'b001) ? S1 : S0;
            S1: next_state = (data == 3'b101) ? S2 : S0;
            S2: next_state = (data == 3'b110) ? S3 : S0;
            S3: next_state = (data == 3'b000) ? S4 : S0;
            S4: next_state = (data == 3'b110) ? S5 : S0;
            S5: next_state = (data == 3'b110) ? S6 : S0;
            S6: next_state = (data == 3'b011) ? S7 : S0;
            S7: next_state = S0;
            default: next_state = S0;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S0;
            prev_state <= S0;
        end else begin
            prev_state <= state;
            state <= next_state;
        end
    end

    assign sequence_found = (prev_state == S6) && (data == 3'b011) || 
                            (prev_state == S7) && (data == 3'b101);

endmodule
