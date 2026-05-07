`default_netname none

// =============================================================
// Tiny Tapeout Top-Level Module
// Simple Access Control System with Keypad Interface
// =============================================================
//
// PIN ASSIGNMENTS:
//
// INPUTS (ui_in[7:0]):
//   [3:0] - Keypad column sense (requires external 10kΩ pull-ups)
//   [4]   - Door sensor (1 = door open, 0 = door closed)
//   [5]   - Admin reset button (rising edge clears alarm state)
//   [6]   - Program mode switch (rising edge stores new password)
//   [7]   - Unused
//
// BIDIRECTIONAL (uio[7:0]):
//   [3:0] - Keypad row drive (outputs, active-low scanning)
//   [7:4] - Unused (configured as inputs)
//
// OUTPUTS (uo_out[7:0]):
//   [0]   - Unlock signal (1 = door unlocked)
//   [1]   - Red LED (1 = access denied or alarm)
//   [2]   - Alarm buzzer (1 = alarm active)
//   [3]   - Keypad lockout (1 = keypad disabled during alarm)
//   [7:4] - Unused
//
// DEFAULT PASSWORD: 0xA2B3 (keys: A-2-B-3)
//
// KEYPAD LAYOUT (4×4 matrix):
//   1  2  3  A
//   4  5  6  B
//   7  8  9  C
//   D  0  E  F
//
// OPERATION:
//   1. Enter 4-digit code on keypad
//   2. Correct code → unlock_signal goes high for 5 seconds
//   3. Open door within 5s → system monitors door state
//   4. Close door → system locks automatically
//   5. 3 wrong codes → alarm state (requires admin reset)
//   6. Door open >30s → alarm state
//
// PROGRAMMING NEW PASSWORD:
//   1. Flip program_mode switch to HIGH
//   2. Enter desired 4-digit code
//   3. Flip program_mode switch to LOW
//   4. New password is stored (lost on reset)
//
// =============================================================

module tt_um_simple_access_control (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Power enable (always 1 when powered)
    input  wire       clk,      // Clock (10 MHz typical for TT06)
    input  wire       rst_n     // Active-low reset
);

    // =============================================================
    // I/O Configuration
    // =============================================================
    
    // Configure uio[3:0] as outputs (keypad rows), uio[7:4] as inputs
    assign uio_oe = 8'b00001111;
    
    // Tie off unused output bits
    assign uio_out[7:4] = 4'b0000;
    assign uo_out[7:4]  = 4'b0000;
    
    // =============================================================
    // Internal Signals
    // =============================================================
    
    // Keypad interface
    wire [3:0] row_drive;
    wire [3:0] col_sense;
    wire [3:0] key_code;
    wire       key_pressed;
    
    // Password verification
    wire code_correct;
    
    // Timer signals
    wire timer_5s_done;
    wire timer_30s_done;
    wire start_5s_timer;
    wire start_30s_timer;
    
    // Control signals
    wire door_sensor;
    wire admin_reset;
    wire program_mode;
    
    // Output signals
    wire unlock_signal;
    wire red_led;
    wire alarm_buzzer;
    wire keypad_lockout;
    
    // =============================================================
    // Pin Mapping
    // =============================================================
    
    // Inputs
    assign col_sense    = ui_in[3:0];  // Keypad columns (need external pull-ups)
    assign door_sensor  = ui_in[4];    // Door sensor
    assign admin_reset  = ui_in[5];    // Admin reset button
    assign program_mode = ui_in[6];    // Password programming switch
    
    // Bidirectional outputs
    assign uio_out[3:0] = row_drive;   // Keypad rows (active-low scan)
    
    // Outputs
    assign uo_out[0] = unlock_signal;  // Door unlock control
    assign uo_out[1] = red_led;        // Access denied / alarm indicator
    assign uo_out[2] = alarm_buzzer;   // Alarm sound output
    assign uo_out[3] = keypad_lockout; // Keypad disable during alarm
    
    // =============================================================
    // Module Instantiations
    // =============================================================
    
    // 1. Keypad Scanner
    //    Scans 4×4 matrix keypad and outputs detected key code
    keypad_scanner scanner_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .col_sense  (col_sense),
        .row_drive  (row_drive),
        .key_code   (key_code),
        .key_pressed(key_pressed)
    );
    
    // 2. Input Buffer with Dynamic Password
    //    Stores user input and compares against stored password
    //    Supports dynamic password programming via program_mode
    input_buffer buffer_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .key_pressed (key_pressed),
        .key_code    (key_code),
        .program_mode(program_mode),
        .code_correct(code_correct)
    );
    
    // 3. 5-Second Timer
    //    Timeout for granted state (door must be opened within 5s)
    //    50,000,000 cycles @ 10 MHz = 5.0 seconds
    countdown_timer #(
        .MAX_COUNT(50_000_000)
    ) timer_5s_inst (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start_5s_timer),
        .done (timer_5s_done)
    );
    
    // 4. 30-Second Timer
    //    Timeout for door open state (triggers alarm if exceeded)
    //    300,000,000 cycles @ 10 MHz = 30.0 seconds
    countdown_timer #(
        .MAX_COUNT(300_000_000)
    ) timer_30s_inst (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start_30s_timer),
        .done (timer_30s_done)
    );
    
    // 5. Access Control Finite State Machine
    //    Main control logic for access control system
    //    States: IDLE, VERIFY, GRANTED, DENIED, OPEN, ALARM
    access_control fsm_inst (
        .clk             (clk),
        .reset_n         (rst_n),
        .user_input_ready(key_pressed),
        .code_correct    (code_correct),
        .door_sensor     (door_sensor),
        .timer_5s_done   (timer_5s_done),
        .timer_30s_done  (timer_30s_done),
        .admin_reset     (admin_reset),
        .unlock_signal   (unlock_signal),
        .red_led         (red_led),
        .alarm_buzzer    (alarm_buzzer),
        .keypad_lockout  (keypad_lockout),
        .start_5s_timer  (start_5s_timer),
        .start_30s_timer (start_30s_timer)
    );
    
    // =============================================================
    // Unused Signal Handling (suppress warnings)
    // =============================================================
    wire _unused = &{ui_in[7], uio_in, ena, 1'b0};

endmodule

// =============================================================
// HARDWARE NOTES FOR PCB DESIGN:
// =============================================================
//
// 1. KEYPAD CONNECTIONS:
//    - Rows (uio[3:0]): Connect directly to keypad row pins
//    - Cols (ui_in[3:0]): Connect to keypad column pins with
//      10kΩ pull-up resistors to VDD (3.3V)
//    - Sky130 input pads have NO internal pull-ups
//
// 2. DOOR SENSOR (ui_in[4]):
//    - Connect to magnetic reed switch or IR sensor
//    - HIGH when door is open, LOW when closed
//    - Add debouncing capacitor (100nF) if using mechanical switch
//
// 3. ADMIN RESET (ui_in[5]):
//    - Connect to momentary push button
//    - Rising edge detection in firmware
//    - Add debouncing (100nF cap + 10kΩ pull-down)
//
// 4. PROGRAM MODE (ui_in[6]):
//    - Connect to toggle switch or button
//    - Rising edge triggers password save
//    - Pull-down resistor recommended (10kΩ)
//
// 5. OUTPUTS:
//    - unlock_signal: Drive relay or electronic lock (via driver)
//    - red_led: Drive LED with current-limiting resistor (330Ω)
//    - alarm_buzzer: Drive piezo buzzer (via transistor)
//    - keypad_lockout: Optional LED indicator
//
// 6. POWER:
//    - All I/O levels: 3.3V CMOS
//    - Do NOT exceed 3.3V on any input
//    - Maximum output current: 4mA per pin
//    - Use external drivers for loads >4mA
//
// =============================================================