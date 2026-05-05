module access_control (
    input clk,
    input reset_n,          // Active low reset
    input user_input_ready, // Signal that user has finished entering code
    input code_correct,     // Comparator result (1 if match, 0 if fail)
    input door_sensor,      // 1 if door is physically open
    input timer_5s_done,    // External timer signal for S2
    input timer_30s_done,   // External timer signal for S4
    input admin_reset,      // Manual reset for S5 lockout
    
    output reg unlock_signal,
    output reg red_led,
    output reg alarm_buzzer,
    output reg keypad_lockout
);

    // State Encoding
    parameter S0_IDLE    = 3'b000;
    parameter S1_VERIFY  = 3'b001;
    parameter S2_GRANTED = 3'b010;
    parameter S3_DENIED  = 3'b011;
    parameter S4_OPEN    = 3'b100;
    parameter S5_ALARM   = 3'b101;

    reg [2:0] current_state, next_state;
    reg [1:0] fail_counter;

    // --- State Transition Logic ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            current_state <= S0_IDLE;
        else
            current_state <= next_state;
    end

    // --- Next State Logic ---
    always @(*) begin
        next_state = current_state; // Default hold state
        
        case (current_state)
            S0_IDLE: begin
                if (user_input_ready) next_state = S1_VERIFY;
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
            
            S3_DENIED: begin
                if (fail_counter >= 3) 
                    next_state = S5_ALARM;
                else 
                    next_state = S0_IDLE;
            end
            
            S4_OPEN: begin
                if (!door_sensor) 
                    next_state = S0_IDLE;
                else if (timer_30s_done) 
                    next_state = S5_ALARM;
            end
            
            S5_ALARM: begin
                if (admin_reset) next_state = S0_IDLE;
            end
            
            default: next_state = S0_IDLE;
        endcase
    end

    // --- Fail Counter Logic ---
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            fail_counter <= 0;
        end else if (current_state == S1_VERIFY && !code_correct) begin
            fail_counter <= fail_counter + 1;
        end else if (current_state == S2_GRANTED) begin
            fail_counter <= 0; // Reset counter on success
        end else if (admin_reset) begin
            fail_counter <= 0; // Reset counter on admin intervention
        end
    end

    // --- Output Logic (Moore Machine) ---
    always @(*) begin
        // Initialize all outputs to 0
        unlock_signal  = 0;
        red_led        = 0;
        alarm_buzzer   = 0;
        keypad_lockout = 0;

        case (current_state)
            S2_GRANTED: unlock_signal = 1;
            S3_DENIED:  red_led = 1;
            S4_OPEN:    unlock_signal = 1;
            S5_ALARM:   begin
                alarm_buzzer = 1;
                keypad_lockout = 1;
            end
        endcase
    end

endmodule