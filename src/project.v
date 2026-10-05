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

    // ui_in[0]=pulse_in, ui_in[1]=user reset, ui_in[3:2]=mode, ui_in[7:4]=duration
    // uo_out[0]=pulse_out
    // MODES: 00=IGNORE while busy, 01=RETRIGGER, 10=EXTEND, 11=RETRIGGER
    // Only posedge clk is used. No delays, no other clocks.

    wire       pulse_in   = ui_in[0];
    wire       user_reset = ui_in[1];
    wire [1:0] mode       = ui_in[3:2];
    wire [3:0] duration   = ui_in[7:4];

    wire [11:0] load_val = (duration == 4'd0) ? 12'd1 : {8'd0, duration};

    // 2-flop synchronizer + edge detector
    reg pulse_in_s1;
    reg pulse_in_s2;
    reg pulse_in_d;
    wire rising_edge = pulse_in_s2 & ~pulse_in_d;

    reg        pulse_out;
    reg [11:0] counter;

    always @(posedge clk) begin
        if (!rst_n || user_reset) begin
            pulse_in_s1 <= 1'b0;
            pulse_in_s2 <= 1'b0;
            pulse_in_d  <= 1'b0;
            pulse_out   <= 1'b0;
            counter     <= 12'd0;
        end else begin
            pulse_in_s1 <= pulse_in;
            pulse_in_s2 <= pulse_in_s1;
            pulse_in_d  <= pulse_in_s2;

            if (rising_edge && (mode != 2'b00 || !pulse_out)) begin
                pulse_out <= 1'b1;
                if (mode == 2'b10 && counter != 12'd0)
                    counter <= counter + {8'd0, duration};
                else
                    counter <= load_val;
            end
            else if (pulse_out) begin
                if (counter > 12'd1) begin
                    counter   <= counter - 12'd1;
                    pulse_out <= 1'b1;
                end else begin
                    counter   <= 12'd0;
                    pulse_out <= 1'b0;
                end
            end
            else begin
                pulse_out <= 1'b0;
                counter   <= 12'd0;
            end
        end
    end

    assign uo_out[0]   = pulse_out;
    assign uo_out[7:1] = 7'b0;
    assign uio_out     = 8'b0;
    assign uio_oe      = 8'b0;

    wire _unused = &{ena, uio_in, 1'b0};

endmodule
