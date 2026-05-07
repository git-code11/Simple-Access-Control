
// maximum digit of password
`define MAX_DIGIT 4
`define DIGIT_BIT_SIZE $clog2(`MAX_DIGIT)

// length of input password
`define PASSWORD_LENGHT 4
`define PASSWORD_LENGTH_BIT_SIZE $clog2(`PASSWORD_LENGHT)

// the bcd bitwidth of representing input password
`define BCD_WIDTH `PASSWORD_LENGHT * `DIGIT_BIT_SIZE

module code_correct (
    input clk,
    input rst_n,
    input [4:0] keys,
    output reg [2:0] rgb_out
);

  // Constant

  // Password encoded using BCD format =  2537
  wire [`BCD_WIDTH-1:0] bcd_password = {3'd2, 3'd5, 3'd3, 3'd7};

  function compare(
    input wire [`BCD_WIDTH-1:0] bcd,
    input wire [`DIGIT_BIT_SIZE-1:0] value,
    input wire [`PASSWORD_LENGTH_BIT_SIZE:0] index
  );
    case(index)
      3'd3: compare = value?0:1
      // 3'd2:
      // 3'd1:
      // 3'd0:
      default:
        compare = 0;
    endcase

  endfunction

  // Password index counter
  reg [`PASSWORD_LENGTH_BIT_SIZE-1:0] pic;

  // FSM State Definitions
  localparam ST_IDLE = 2'b00, ST_CHECK = 2'b01, ST_SUCCESS = 2'b10, ST_FAIL = 2'b11;
  reg [1:0] current_state, next_state;

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

  // FSM State Transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= ST_IDLE;
    else current_state <= next_state;
  end

  // Timer to switch


  // Output and Next-State Logic
  always @(*) begin
    next_state = current_state;  // Default to hold state
    if (!rst_n) begin
      rgb_out = 3'b000;
      next_state = ST_IDLE;
      pic = 0;
    end else begin
      case (current_state)
        ST_IDLE: begin
          rgb_out = 3'b000;
        end

        ST_CHECK: begin
          rgb_out = 3'b100;
          if (is_pressed) begin
            if()
          end else begin
            next_state = ST_CHECK;
          end
          pic = pic + 1;
        end

        ST_SUCCESS: begin
          rgb_out = 3'b010;
          next_state = ST_SUCCESS;  // Stay until reset
        end

        ST_FAIL: begin
          rgb_out = 3'b100;
          next_state = ST_FAIL;  // Stay until reset
        end

        default: next_state = ST_IDLE;  // Failsafe reset
      endcase
    end
  end
endmodule

