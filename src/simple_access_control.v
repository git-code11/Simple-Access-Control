
// maximum digit of password
`define MAX_DIGIT 4
`define DIGIT_BIT_SIZE $clog2(`MAX_DIGIT)

// length of input password
`define PASSWORD_LENGHT 4
`define PASSWORD_LENGTH_BIT_SIZE $clog2(`PASSWORD_LENGHT)

// the bcd bitwidth of representing input password
`define BCD_WIDTH `PASSWORD_LENGHT * `DIGIT_BIT_SIZE

module simple_access_control (
    input clk,
    input rst_n,
    input [4:0] keys,
    ouput is_unlocked,
    output reg [2:0] rgb_out
  );

  // Password encoded using BCD format =  2143
  wire [`BCD_WIDTH-1:0] bcd_password = {3'd2, 3'd1, 3'd4, 3'd3};

  // FSM State Definitions
  localparam  ST_IDLE = 3'd0,
              ST_CHECK_0 = 3'd1, 
              ST_CHECK_1 = 3'd2,
              ST_CHECK_2 = 3'd3,
              ST_CHECK_3 = 3'd4,
              ST_SUCCESS = 3'd5,
              ST_FAIL = 3'd6;

  reg [2:0] current_state, next_state;

  // Keypad Module
  wire is_pressed;
  wire [3:0] value;

  keypad5 keypad (
            .clk(clk),
            .rst_n(rst_n),
            .keys(keys),
            .is_pressed(is_pressed),
            .value(value)
          );

  // Output logic for unlocking mechanism
  assign is_unlocked = (current_state == ST_SUCCESS) ? 1 : 0;

  // Function to compare input digit with password digit
  function compare(
      input [`BCD_WIDTH-1:0] bcd,
      input [`DIGIT_BIT_SIZE-1:0] value,
      input [`PASSWORD_LENGTH_BIT_SIZE:0] index
    );
    case(index)
      (`PASSWORD_LENGTH_BIT_SIZE)'d3:
        compare = (value == bcd[`DIGIT_BIT_SIZE-1:0])?1:0;
      (`PASSWORD_LENGTH_BIT_SIZE)'d2:
        compare = (value == bcd[2*`DIGIT_BIT_SIZE-1:`DIGIT_BIT_SIZE])?1:0;
      (`PASSWORD_LENGTH_BIT_SIZE)'d1:
        compare = (value == bcd[3*`DIGIT_BIT_SIZE-1:2*`DIGIT_BIT_SIZE])?1:0;
      (`PASSWORD_LENGTH_BIT_SIZE)'d0:
        compare = (value == bcd[4*`DIGIT_BIT_SIZE-1:3*`DIGIT_BIT_SIZE])?1:0;
      default:
        compare = 0;
    endcase
  endfunction

  // Function to determine next state based on current input and state
  function [2:0] determine_next_state(
      input [`BCD_WIDTH-1:0] bcd,
      input [`DIGIT_BIT_SIZE-1:0] value,
      input [`PASSWORD_LENGTH_BIT_SIZE:0] index,
      input is_pressed,
      input [2:0] current_state,
      input [2:0] next_state_positive,
      input [2:0] next_state_negative
    );
    if(is_pressed) begin
      if(compare(bcd, value, index)) begin
        determine_next_state = next_state_positive; // Move to next CHECK state
      end else
        determine_next_state = next_state_negative;
    end
    else begin
      determine_next_state = current_state; // Stay in current state until a key is pressed
    end
  endfunction

  // FSM State Transition
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
      current_state <= ST_IDLE;
    else
      current_state <= next_state;
  end

  // Light Status LEDs based on current state
  always @(*)
  begin
    case (current_state)
      ST_CHECK_0, ST_CHECK_1, ST_CHECK_2, ST_CHECK_3:
        rgb_out = 3'b001;  // BLUE LED on
      ST_SUCCESS:
        rgb_out = 3'b010;  // Green LED on
      ST_FAIL:
        rgb_out = 3'b100;  // Red LED on
      default:
        rgb_out = 3'b000; // All LEDs off
    endcase
  end

  

  // Output and Next-State Logic
  always @(*)
  begin
      case (current_state)
        ST_IDLE:
        begin
          if (is_pressed)
            next_state = ST_CHECK_0;  // Move to CHECK state on key press
          else
            next_state = ST_IDLE;  // Stay in IDLE until a key is pressed
        end

        ST_CHECK_0:
        begin
          next_state = determine_next_state(
            bcd_password, 
            value, 
            0, 
            is_pressed, 
            current_state, 
            ST_CHECK_1,
            ST_FAIL);
        end

        ST_CHECK_1:
        begin
          next_state = determine_next_state(
            bcd_password, 
            value, 
            1, 
            is_pressed, 
            current_state, 
            ST_CHECK_2,
            ST_FAIL);
        end 
        
        ST_CHECK_2:
        begin
          next_state = determine_next_state(
            bcd_password, 
            value, 
            2, 
            is_pressed, 
            current_state, 
            ST_CHECK_3,
            ST_FAIL);
        end
        
        ST_CHECK_3:
        begin
          next_state = determine_next_state(
            bcd_password, 
            value, 
            3, 
            is_pressed, 
            current_state, 
            ST_SUCCESS,
            ST_FAIL);
        end

        ST_SUCCESS:
        begin
          next_state = ST_SUCCESS;
        end

        ST_FAIL:
        begin
          next_state = ST_FAIL;  // Stay until reset
        end

        default:
          next_state = ST_IDLE;  // Failsafe reset
      endcase
    end
endmodule