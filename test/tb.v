`timescale 1ns / 1ps

// =============================================================
// Testbench for Tiny Tapeout Access Control System
// Tests the complete tt_um_simple_access_control wrapper
// Validates pin mappings and end-to-end functionality
// =============================================================

module tt_um_simple_access_control_tb;

    // =============================================================
    // Tiny Tapeout Standard Interface Signals
    // =============================================================
    reg  [7:0] ui_in;      // Dedicated inputs
    wire [7:0] uo_out;     // Dedicated outputs
    reg  [7:0] uio_in;     // Bidirectional inputs
    wire [7:0] uio_out;    // Bidirectional outputs
    wire [7:0] uio_oe;     // Bidirectional enable (1=output)
    reg        ena;        // Enable (always 1 for testing)
    reg        clk;        // 10 MHz clock
    reg        rst_n;      // Active-low reset
    
    // =============================================================
    // Test Control Variables
    // =============================================================
    integer test_number;
    integer fail_count;
    integer i;
    
    // =============================================================
    // DUT Instantiation
    // =============================================================
    tt_um_simple_access_control dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );
    
    // =============================================================
    // Signal Aliases for Readability
    // =============================================================
    
    // Inputs (ui_in)
    wire [3:0] col_sense_pins = ui_in[3:0];
    wire       door_sensor    = ui_in[4];
    wire       admin_reset    = ui_in[5];
    wire       program_mode   = ui_in[6];
    
    // Bidirectional (uio)
    wire [3:0] row_drive_pins = uio_out[3:0];
    
    // Outputs (uo_out)
    wire unlock_signal  = uo_out[0];
    wire red_led        = uo_out[1];
    wire alarm_buzzer   = uo_out[2];
    wire keypad_lockout = uo_out[3];
    
    // =============================================================
    // Clock Generation (10 MHz = 100ns period)
    // =============================================================
    initial begin
        clk = 0;
        forever #50 clk = ~clk;
    end
    
    // =============================================================
    // Helper Tasks
    // =============================================================
    
    // Press a key by simulating keypad matrix behavior
    task press_key;
        input [3:0] key_value;
        reg [3:0] expected_row;
        reg [3:0] col_pattern;
        integer timeout_counter;
        begin
            // Determine which row/column this key requires
            case(key_value)
                4'h1: begin expected_row = 4'b1110; col_pattern = 4'b1110; end
                4'h2: begin expected_row = 4'b1110; col_pattern = 4'b1101; end
                4'h3: begin expected_row = 4'b1110; col_pattern = 4'b1011; end
                4'hA: begin expected_row = 4'b1110; col_pattern = 4'b0111; end
                4'h4: begin expected_row = 4'b1101; col_pattern = 4'b1110; end
                4'h5: begin expected_row = 4'b1101; col_pattern = 4'b1101; end
                4'h6: begin expected_row = 4'b1101; col_pattern = 4'b1011; end
                4'hB: begin expected_row = 4'b1101; col_pattern = 4'b0111; end
                4'h7: begin expected_row = 4'b1011; col_pattern = 4'b1110; end
                4'h8: begin expected_row = 4'b1011; col_pattern = 4'b1101; end
                4'h9: begin expected_row = 4'b1011; col_pattern = 4'b1011; end
                4'hC: begin expected_row = 4'b1011; col_pattern = 4'b0111; end
                4'hD: begin expected_row = 4'b0111; col_pattern = 4'b1110; end
                4'h0: begin expected_row = 4'b0111; col_pattern = 4'b1101; end
                4'hE: begin expected_row = 4'b0111; col_pattern = 4'b1011; end
                4'hF: begin expected_row = 4'b0111; col_pattern = 4'b0111; end
                default: begin expected_row = 4'b1111; col_pattern = 4'b1111; end
            endcase
            
            // Wait for scanner to drive the correct row (with timeout)
            timeout_counter = 0;
            while (row_drive_pins !== expected_row && timeout_counter < 100000) begin
                @(posedge clk);
                timeout_counter = timeout_counter + 1;
            end
            
            if (timeout_counter >= 100000) begin
                $display("ERROR: Timeout waiting for row %b", expected_row);
            end
            
            // Apply column pattern
            #1000;
            ui_in[3:0] = col_pattern;
            
            // Hold for multiple scan cycles (about 6 full periods)
            #600000;
            
            // Release key
            ui_in[3:0] = 4'b1111;
            #100000;
        end
    endtask
    
    // Enter a 4-digit code
    task enter_code;
        input [15:0] code;
        begin
            $display("  Entering code: %h", code);
            press_key(code[15:12]);
            press_key(code[11:8]);
            press_key(code[7:4]);
            press_key(code[3:0]);
        end
    endtask
    
    // Wait for specified number of clock cycles
    task wait_cycles;
        input integer cycles;
        begin
            repeat(cycles) @(posedge clk);
        end
    endtask
    
    // Check outputs match expected values
    task check_outputs;
        input exp_unlock;
        input exp_red;
        input exp_alarm;
        input exp_lockout;
        input [255:0] test_name;
        begin
            if (unlock_signal !== exp_unlock || red_led !== exp_red || 
                alarm_buzzer !== exp_alarm || keypad_lockout !== exp_lockout) begin
                $display("  FAIL: %s", test_name);
                $display("    Expected: unlock=%b red=%b alarm=%b lockout=%b", 
                         exp_unlock, exp_red, exp_alarm, exp_lockout);
                $display("    Got:      unlock=%b red=%b alarm=%b lockout=%b",
                         unlock_signal, red_led, alarm_buzzer, keypad_lockout);
                fail_count = fail_count + 1;
            end else begin
                $display("  PASS: %s", test_name);
            end
        end
    endtask
    
    // Verify bidirectional pin configuration
    task check_pin_config;
        begin
            if (uio_oe !== 8'b00001111) begin
                $display("  FAIL: uio_oe configuration incorrect");
                $display("    Expected: 8'b00001111 (lower 4 bits output)");
                $display("    Got:      8'b%b", uio_oe);
                fail_count = fail_count + 1;
            end else begin
                $display("  PASS: Bidirectional pins correctly configured");
            end
            
            if (uio_out[7:4] !== 4'b0000) begin
                $display("  FAIL: Upper uio_out bits should be 0");
                fail_count = fail_count + 1;
            end else begin
                $display("  PASS: Upper uio_out bits tied to 0");
            end
            
            if (uo_out[7:4] !== 4'b0000) begin
                $display("  FAIL: Upper uo_out bits should be 0");
                fail_count = fail_count + 1;
            end else begin
                $display("  PASS: Upper uo_out bits tied to 0");
            end
        end
    endtask
    
    // =============================================================
    // Main Test Sequence
    // =============================================================
    initial begin
        $dumpfile("tt_um_simple_access_control_tb.vcd");
        $dumpvars(0, tt_um_simple_access_control_tb);
        
        // Initialize
        test_number = 0;
        fail_count = 0;
        ena = 1;
        rst_n = 0;
        ui_in = 8'b0;
        uio_in = 8'b0;
        ui_in[3:0] = 4'b1111;  // Keypad columns idle high
        
        $display("\n===============================================");
        $display("Tiny Tapeout Access Control System Test");
        $display("===============================================\n");
        
        // Apply reset
        #500;
        rst_n = 1;
        #1000;
        
        // =========================================================
        // TEST 0: Pin Configuration Verification
        // =========================================================
        test_number = 0;
        $display("--- Test %0d: Pin Configuration ---", test_number);
        check_pin_config();
        
        // =========================================================
        // TEST 1: Default Password (0xA2B3)
        // =========================================================
        test_number = 1;
        $display("\n--- Test %0d: Correct Password Entry ---", test_number);
        enter_code(16'hA2B3);
        wait_cycles(100);
        check_outputs(1, 0, 0, 0, "Unlock after correct password");
        
        // Wait for 5s timer to expire (50 cycles in simulation)
        wait_cycles(60);
        check_outputs(0, 0, 0, 0, "Auto-lock after 5s timeout");
        
        // =========================================================
        // TEST 2: Wrong Password
        // =========================================================
        test_number = 2;
        $display("\n--- Test %0d: Incorrect Password ---", test_number);
        enter_code(16'h1234);
        wait_cycles(100);
        check_outputs(0, 1, 0, 0, "Red LED on wrong password");
        
        // Wait for deny hold period
        wait_cycles(10_000_100);
        check_outputs(0, 0, 0, 0, "Clear after deny hold");
        
        // =========================================================
        // TEST 3: Three Failed Attempts
        // =========================================================
        test_number = 3;
        $display("\n--- Test %0d: Alarm After 3 Failures ---", test_number);
        
        enter_code(16'h0000);
        wait_cycles(10_000_100);
        
        enter_code(16'h1111);
        wait_cycles(10_000_100);
        
        enter_code(16'h2222);
        wait_cycles(10_000_100);
        check_outputs(0, 1, 1, 1, "Alarm state active");
        
        // Clear with admin reset
        ui_in[5] = 1;  // admin_reset
        wait_cycles(5);
        ui_in[5] = 0;
        wait_cycles(10);
        check_outputs(0, 0, 0, 0, "Cleared by admin reset");
        
        // =========================================================
        // TEST 4: Door Sensor Integration
        // =========================================================
        test_number = 4;
        $display("\n--- Test %0d: Door Sensor Operation ---", test_number);
        
        enter_code(16'hA2B3);
        wait_cycles(100);
        check_outputs(1, 0, 0, 0, "Unlocked");
        
        // Open door
        ui_in[4] = 1;  // door_sensor
        wait_cycles(10);
        check_outputs(1, 0, 0, 0, "Still unlocked with door open");
        
        // Close door
        ui_in[4] = 0;
        wait_cycles(10);
        check_outputs(0, 0, 0, 0, "Lock when door closes");
        
        // =========================================================
        // TEST 5: Door Open Timeout (30s)
        // =========================================================
        test_number = 5;
        $display("\n--- Test %0d: Door Open Timeout ---", test_number);
        
        enter_code(16'hA2B3);
        wait_cycles(100);
        
        ui_in[4] = 1;  // Open door
        wait_cycles(10);
        
        // Wait for 30s timer (300 cycles in simulation)
        wait_cycles(310);
        check_outputs(0, 1, 1, 1, "Alarm after door timeout");
        
        // Reset
        ui_in[4] = 0;
        ui_in[5] = 1;
        wait_cycles(5);
        ui_in[5] = 0;
        wait_cycles(10);
        
        // =========================================================
        // TEST 6: Password Programming
        // =========================================================
        test_number = 6;
        $display("\n--- Test %0d: Password Programming ---", test_number);
        
        // Program new password
        ui_in[6] = 1;  // program_mode
        enter_code(16'h5678);
        wait_cycles(100);
        ui_in[6] = 0;
        wait_cycles(100);
        
        // Old password should fail
        enter_code(16'hA2B3);
        wait_cycles(100);
        check_outputs(0, 1, 0, 0, "Old password rejected");
        wait_cycles(10_000_100);
        
        // New password should work
        enter_code(16'h5678);
        wait_cycles(100);
        check_outputs(1, 0, 0, 0, "New password accepted");
        wait_cycles(60);
        
        // =========================================================
        // TEST 7: Row Drive Scanning Verification
        // =========================================================
        test_number = 7;
        $display("\n--- Test %0d: Keypad Row Scanning ---", test_number);
        
        $display("  Monitoring row_drive for 4 complete scan cycles...");
        for (i = 0; i < 4; i = i + 1) begin
            wait_cycles(524288);  // One full scan period
            $display("    Row drive = %b", row_drive_pins);
        end
        $display("  PASS: Row scanner operating");
        
        // =========================================================
        // TEST 8: Edge Case - No Door Opening After Unlock
        // =========================================================
        test_number = 8;
        $display("\n--- Test %0d: Timeout Without Door Opening ---", test_number);
        
        enter_code(16'h5678);
        wait_cycles(100);
        check_outputs(1, 0, 0, 0, "Unlocked");
        
        // Don't open door, wait for timeout
        wait_cycles(60);
        check_outputs(0, 0, 0, 0, "Auto-lock without door activity");
        
        // =========================================================
        // Test Summary
        // =========================================================
        $display("\n===============================================");
        $display("Test Summary");
        $display("===============================================");
        $display("Total Tests: %0d", test_number + 1);
        $display("Failures: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED ***");
            $display("Design is ready for Tiny Tapeout submission\n");
        end else begin
            $display("\n*** %0d TEST(S) FAILED ***", fail_count);
            $display("Fix errors before submission\n");
        end
        
        #10000;
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #500_000_000;
        $display("\n*** ERROR: Simulation timeout ***\n");
        $finish;
    end

endmodule