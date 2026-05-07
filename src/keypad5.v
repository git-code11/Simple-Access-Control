
/**
* Keypad with only five unique digit support
* Digits are: 0, 1, 2, 3, 4
*/

`define MAX_DIGIT 4
`define BIT_SIZE $clog2(`MAX_DIGIT)

module keypad5 #(
    parameter CLK_FREQ = 50_000_000,  // Clock frequency in Hz
    parameter DEBOUNCE_TIME_MS = 20
) (
    input clk,
    input rst_n,
    input [`MAX_DIGIT:0] keys,
    output is_pressed,
    output reg [`BIT_SIZE - 1:0] value
);


  wire debounced_key;

  debouncer #(
      .BIT_WIDTH(`MAX_DIGIT + 1),
      .DEBOUNCE_TIME_MS(DEBOUNCE_TIME_MS),
      .CLK_FREQ(CLK_FREQ)
  ) debouncer (
      .clk(clk),
      .rst_n(rst_n),
      .button_in(keys),
      .button_out(debounced_key)
  );

  assign is_pressed = |{debounced_key};

  always @(keys) begin
    // TODO replace with a onehot
    case (1'b1)
      keys[0]: value = 3'd0;
      keys[1]: value = 3'd1;
      keys[2]: value = 3'd2;
      keys[3]: value = 3'd3;
      keys[4]: value = 3'd4;
      default: value = 3'd0;
    endcase
  end

endmodule

