module simple_access_control (
    input clk,
    input rst_n,
    input [3:0] row,
    output [3:0] col,
    output reg [2:0] rgb_out
);
  // FSM State Definitions
  localparam ST_IDLE = 2'b00, ST_CHECK = 2'b01, ST_SUCCESS = 2'b10, ST_FAIL = 2'b11;

  reg [1:0] current_state, next_state;
  wire _unused = &{row, col, 1'b1};  // PIN WOULD STILL BE NEEDED

  // Sub-modules
  // KEYPAD_SCANNER

  // DEBOUNCER

  // FSM State Transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= ST_IDLE;
    else current_state <= next_state;
  end

  // Output and Next-State Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rgb_out <= 3'b000;
      next_state <= ST_IDLE;
    end else begin
      case (current_state)
        ST_IDLE: begin
          rgb_out <= 3'b100;
        end

        ST_CHECK: begin
          rgb_out <= 3'b100;
          next_state <= ST_CHECK;
        end

        ST_SUCCESS: begin
          rgb_out <= 3'b010;
          next_state <= ST_SUCCESS;  // Stay until reset
        end

        ST_FAIL: begin
          rgb_out <= 3'b100;
          next_state <= ST_FAIL;  // Stay until reset
        end

        default: next_state <= ST_IDLE;  // Failsafe reset
      endcase
    end
  end
endmodule

