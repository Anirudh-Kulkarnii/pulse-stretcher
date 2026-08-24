`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,     // Dedicated inputs
    output wire [7:0] uo_out,    // Dedicated outputs
    input  wire [7:0] uio_in,    // Bidirectional input path
    output wire [7:0] uio_out,   // Bidirectional output path
    output wire [7:0] uio_oe,    // Bidirectional output enable
    input  wire       ena,       // Enable
    input  wire       clk,       // Clock
    input  wire       rst_n      // Tiny Tapeout active-low reset
);

    // =========================================================
    // INPUT MAPPING
    // =========================================================
    //
    // ui_in[0]   = pulse_in
    // ui_in[1]   = user reset
    // ui_in[3:2] = mode
    // ui_in[7:4] = duration
    //
    // uo_out[0]  = pulse_out
    //
    // =========================================================

    wire       pulse_in;
    wire       user_reset;
    wire [1:0] mode;
    wire [3:0] duration;

    assign pulse_in   = ui_in[0];
    assign user_reset = ui_in[1];
    assign mode       = ui_in[3:2];
    assign duration   = ui_in[7:4];

    // =========================================================
    // INTERNAL SIGNALS
    // =========================================================

    reg pulse_in_d;
    reg pulse_out;
    reg [11:0] counter;

    wire rising_edge;

    assign rising_edge = pulse_in & ~pulse_in_d;

    // =========================================================
    // MAIN PULSE STRETCHER
    // =========================================================

    always @(posedge clk) begin

        // Tiny Tapeout reset OR user reset
        if (!rst_n || user_reset) begin

            pulse_in_d <= 1'b0;
            pulse_out  <= 1'b0;
            counter    <= 12'd0;

        end else begin

            // Store previous input state
            pulse_in_d <= pulse_in;

            // -------------------------------------------------
            // Detect rising edge
            // -------------------------------------------------

            if (rising_edge) begin

                // Mode 00 = IGNORE / NORMAL
                //
                // Start a new stretched pulse.
                if (mode == 2'b00) begin

                    pulse_out <= 1'b1;

                    // Duration cannot be zero.
                    if (duration == 4'd0)
                        counter <= 12'd1;
                    else
                        counter <= {8'd0, duration};

                end

                // -------------------------------------------------
                // Mode 01 = RETRIGGER
                //
                // A new pulse restarts the counter.
                // -------------------------------------------------

                else if (mode == 2'b01) begin

                    pulse_out <= 1'b1;

                    if (duration == 4'd0)
                        counter <= 12'd1;
                    else
                        counter <= {8'd0, duration};

                end

                // -------------------------------------------------
                // Mode 10 = EXTEND
                //
                // New pulse adds another duration to the
                // current stretching period.
                // -------------------------------------------------

                else if (mode == 2'b10) begin

                    pulse_out <= 1'b1;

                    if (counter == 12'd0)
                        counter <= {8'd0, duration};
                    else
                        counter <= counter + {8'd0, duration};

                end

                // -------------------------------------------------
                // Mode 11 = NORMAL / RETRIGGER
                // -------------------------------------------------

                else begin

                    pulse_out <= 1'b1;

                    if (duration == 4'd0)
                        counter <= 12'd1;
                    else
                        counter <= {8'd0, duration};

                end

            end

            // =====================================================
            // COUNTER OPERATION
            // =====================================================

            else if (pulse_out) begin

                if (counter > 12'd1) begin

                    counter <= counter - 12'd1;
                    pulse_out <= 1'b1;

                end else begin

                    counter <= 12'd0;
                    pulse_out <= 1'b0;

                end

            end

            // =====================================================
            // IDLE
            // =====================================================

            else begin

                pulse_out <= 1'b0;
                counter   <= 12'd0;

            end

        end

    end

    // =========================================================
    // OUTPUT
    // =========================================================

    assign uo_out[0] = pulse_out;

    // Unused outputs
    assign uo_out[7:1] = 7'b0;

    // No bidirectional pins used
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule

