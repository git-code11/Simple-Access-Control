module access_control (
    input  wire clk,
    input  wire reset_n,
    input  wire user_input_ready,
    input  wire code_correct,
    input  wire door_sensor,
    input  wire timer_5s_done,
    input  wire timer_30s_done,
    input  wire admin_reset,

    output reg  unlock_signal,
    output reg  red_led,
    output reg  alarm_buzzer,
    output reg  keypad_lockout,

    // FIX: timer start pulses — connect to countdown_timer instances in top module
    output reg  start_5s_timer,
    output reg  start_30s_timer
);

    // FIX: localparam instead of parameter (not overridable from outside)
    localparam [2:0]
        S0_IDLE    = 3'b000,
        S1_VERIFY  = 3'b001,
        S2_GRANTED = 3'b010,
        S3_DENIED  = 3'b011,
        S4_OPEN    = 3'b100,
        S5_ALARM   = 3'b101;

    reg [2:0] current_state, next_state;
    reg [1:0] fail_counter;
    reg [2:0] prev_state;

    // FIX: 2-stage synchronizer for admin_reset (prevents metastability on silicon)
    reg admin_reset_s1, admin_reset_sync;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            admin_reset_s1   <= 1'b0;
            admin_reset_sync <= 1'b0;
        end else begin
            admin_reset_s1   <= admin_reset;
            admin_reset_sync <= admin_reset_s1;
        end
    end

    // FIX: Denied-state hold counter (~1 second at 10 MHz = 10,000,000 cycles)
    // Using 24-bit counter; 2^24 = 16.7M > 10M so it fits.
    localparam DENY_HOLD = 24'd10_000_000;
    reg [23:0] deny_timer;
    wire       deny_done = (deny_timer == DENY_HOLD - 1);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            deny_timer <= 24'd0;
        end else if (current_state == S3_DENIED) begin
            deny_timer <= deny_done ? 24'd0 : deny_timer + 1;
        end else begin
            deny_timer <= 24'd0;
        end
    end

    // --- State Register ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            current_state <= S0_IDLE;
        else
            current_state <= next_state;
    end

    // --- Next-State Logic ---
    always @(*) begin
        next_state = current_state;

        case (current_state)
            S0_IDLE: begin
                if (user_input_ready)
                    next_state = S1_VERIFY;
            end

            S1_VERIFY: begin
                if (code_correct)
                    next_state = S2_GRANTED;
                else
                    next_state = S3_DENIED;
            end

            S2_GRANTED: begin
                if (door_sensor)
                    next_state = S4_OPEN;
                else if (timer_5s_done)
                    next_state = S0_IDLE;
            end

            // FIX: S3_DENIED now waits for deny_done before leaving state
            // so red_led is visible for ~1 second (not 1 clock cycle)
            S3_DENIED: begin
                if (deny_done) begin
                    if (fail_counter >= 2'd3)
                        next_state = S5_ALARM;
                    else
                        next_state = S0_IDLE;
                end
            end

            S4_OPEN: begin
                if (!door_sensor)
                    next_state = S0_IDLE;
                else if (timer_30s_done)
                    next_state = S5_ALARM;
            end

            S5_ALARM: begin
                if (admin_reset_sync)
                    next_state = S0_IDLE;
            end

            default: next_state = S0_IDLE;
        endcase
    end

    // --- Fail Counter ---
    // FIX: saturates at 3 — no wraparound if unexpected extra pulse occurs
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            fail_counter <= 2'd0;
        end else if (admin_reset_sync) begin
            fail_counter <= 2'd0;
        end else if (current_state == S2_GRANTED) begin
            fail_counter <= 2'd0;                              // success clears counter
        end else if (current_state == S1_VERIFY && !code_correct) begin
            // FIX: only increment if below max — prevents silent wraparound
            if (fail_counter < 2'd3)
                fail_counter <= fail_counter + 1;
        end
    end

    // --- Output Logic (Moore machine — registered to avoid glitches) ---
    always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        unlock_signal   <= 1'b0;
        red_led         <= 1'b0;
        alarm_buzzer    <= 1'b0;
        keypad_lockout  <= 1'b0;
        start_5s_timer  <= 1'b0;
        start_30s_timer <= 1'b0;
        prev_state      <= S0_IDLE;  // ← ADD THIS
    end else begin
        // Update previous state tracker
        prev_state <= current_state;  // ← ADD THIS
        
        // Default: clear timer start pulses
        start_5s_timer  <= 1'b0;
        start_30s_timer <= 1'b0;

        case (current_state)
            S0_IDLE: begin
                unlock_signal  <= 1'b0;
                red_led        <= 1'b0;
                alarm_buzzer   <= 1'b0;
                keypad_lockout <= 1'b0;
            end

            S2_GRANTED: begin
                unlock_signal  <= 1'b1;
                red_led        <= 1'b0;
                alarm_buzzer   <= 1'b0;
                keypad_lockout <= 1'b0;
                // FIXED: Detect state entry
                if (prev_state != S2_GRANTED)  // ← CHANGE THIS LINE
                    start_5s_timer <= 1'b1;
            end

            S3_DENIED: begin
                unlock_signal  <= 1'b0;
                red_led        <= 1'b1;
                alarm_buzzer   <= 1'b0;
                keypad_lockout <= 1'b0;
            end

            S4_OPEN: begin
                unlock_signal  <= 1'b1;
                red_led        <= 1'b0;
                alarm_buzzer   <= 1'b0;
                keypad_lockout <= 1'b0;
                // FIXED: Detect state entry
                if (prev_state != S4_OPEN)  // ← CHANGE THIS LINE
                    start_30s_timer <= 1'b1;
            end

            S5_ALARM: begin
                unlock_signal  <= 1'b0;
                red_led        <= 1'b1;
                alarm_buzzer   <= 1'b1;
                keypad_lockout <= 1'b1;
            end

            default: begin
                unlock_signal  <= 1'b0;
                red_led        <= 1'b0;
                alarm_buzzer   <= 1'b0;
                keypad_lockout <= 1'b0;
            end
        endcase
    end
end

endmodule

// =============================================================
// Sub-module: Keypad Scanner
// FIX (C2): all registers now fully reset
// FIX (C3): row is driven at start of period (scan_timer==0),
//           col is SAMPLED at midpoint (scan_timer==HALF),
//           giving time for signals to propagate and settle.
// =============================================================
module keypad_scanner (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] col_sense,
    output reg  [3:0] row_drive,
    output reg  [3:0] key_code,
    output reg        key_pressed
);
    reg [1:0]  scan_state;
    reg [18:0] scan_timer;

    // Half-period sample point — col is read here, well after row settles
    localparam HALF = 19'h40000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_state  <= 2'b00;
            scan_timer  <= 19'd0;
            row_drive   <= 4'b1110;   // FIX (C2): was uninitialized
            key_code    <= 4'h0;      // FIX (C2): was uninitialized
            key_pressed <= 1'b0;      // FIX (C2): was uninitialized
        end else begin
            scan_timer <= scan_timer + 1;

            // --- Phase 1: drive the next row at the START of the period ---
            // FIX (C3): row_drive and col sensing are now separated in time.
            if (scan_timer == 0) begin
                scan_state <= scan_state + 1;
                case (scan_state)
                    2'b00: row_drive <= 4'b1110;
                    2'b01: row_drive <= 4'b1101;
                    2'b10: row_drive <= 4'b1011;
                    2'b11: row_drive <= 4'b0111;
                endcase
            end

            // --- Phase 2: sample columns at MIDPOINT (after row settles) ---
            // FIX (C3): col_sense is now read against the CURRENT stable row_drive.
            if (scan_timer == HALF) begin
                if (col_sense != 4'b1111) begin
                    key_pressed <= 1'b1;
                    // Use a case on {row, col} concatenation — cleaner and less error-prone
                    casez ({row_drive, col_sense})
                        {4'b1110, 4'b1110}: key_code <= 4'h1;
                        {4'b1110, 4'b1101}: key_code <= 4'h2;
                        {4'b1110, 4'b1011}: key_code <= 4'h3;
                        {4'b1110, 4'b0111}: key_code <= 4'hA; // * (star)
                        {4'b1101, 4'b1110}: key_code <= 4'h4;
                        {4'b1101, 4'b1101}: key_code <= 4'h5;
                        {4'b1101, 4'b1011}: key_code <= 4'h6;
                        {4'b1101, 4'b0111}: key_code <= 4'hB; // # (hash)
                        {4'b1011, 4'b1110}: key_code <= 4'h7;
                        {4'b1011, 4'b1101}: key_code <= 4'h8;
                        {4'b1011, 4'b1011}: key_code <= 4'h9;
                        {4'b1011, 4'b0111}: key_code <= 4'hC; // spare
                        {4'b0111, 4'b1110}: key_code <= 4'hD; // spare
                        {4'b0111, 4'b1101}: key_code <= 4'h0;
                        {4'b0111, 4'b1011}: key_code <= 4'hE; // spare
                        {4'b0111, 4'b0111}: key_code <= 4'hF; // spare
                        default:            key_code <= 4'hF;
                    endcase
                end else begin
                    key_pressed <= 1'b0;
                end
            end
        end
    end
endmodule


// =============================================================
// Sub-module: Input Buffer with Dynamic Password Programming
// FIX (I1): program_mode is now edge-triggered, not level-sensitive
// FIX (I2): shift_reg resets to 0x0000 (not 0xFFFF) and a guard
//           prevents a zero-value match from triggering code_correct
// =============================================================
module input_buffer (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       key_pressed,
    input  wire [3:0] key_code,
    input  wire       program_mode,
    output reg        code_correct
);
    reg [15:0] shift_reg;
    reg [15:0] stored_password;
    reg        old_key_pressed;
    reg        old_program_mode;   // FIX (I1): needed for edge detection

    // Default password — change before tapeout
    localparam [15:0] DEFAULT_PASSWORD = 16'hA2B3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg        <= 16'h0000;         // FIX (I2): was 16'hFFFF
            stored_password  <= DEFAULT_PASSWORD;
            code_correct     <= 1'b0;
            old_key_pressed  <= 1'b0;
            old_program_mode <= 1'b0;
        end else begin
            old_key_pressed  <= key_pressed;
            old_program_mode <= program_mode;

            // Shift in new key on rising edge of key_pressed
            if (key_pressed && !old_key_pressed) begin
                shift_reg <= {shift_reg[11:0], key_code};
            end

            // FIX (I1): program only on RISING EDGE of program_mode switch,
            // not continuously — prevents in-flight overwrites during typing.
            if (program_mode && !old_program_mode) begin
                stored_password <= shift_reg;
                shift_reg       <= 16'h0000; // clear buffer after programming
            end

            // FIX (I2): guard against zero-value false match at startup
            code_correct <= (shift_reg == stored_password) && (shift_reg != 16'h0000);
        end
    end
endmodule


// =============================================================
// Sub-module: Countdown Timer
// FIX (C4/I3): replaces hardwired 1'b0 on timer signals.
// Parameterised — instantiate twice with different MAX_COUNT.
// =============================================================
module countdown_timer #(
    parameter MAX_COUNT = 50_000_000  // default 5s at 10 MHz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire start,   // pulse high for 1 cycle to arm the timer
    output reg  done     // pulses high for 1 cycle when count reaches MAX
);
    reg [28:0] count;
    reg        running;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count   <= 0;
            running <= 1'b0;
            done    <= 1'b0;
        end else begin
            done <= 1'b0; // default: not done

            if (start) begin
                count   <= 0;
                running <= 1'b1;
            end else if (running) begin
                if (count == MAX_COUNT - 1) begin
                    done    <= 1'b1;
                    running <= 1'b0;
                    count   <= 0;
                end else begin
                    count <= count + 1;
                end
            end
        end
    end
endmodule


