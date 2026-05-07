/**
* Debouncer Circuit
* Reference: https://www.chipverify.com/verilog/verilog-debounce-circuit
*/

module debouncer #(
    parameter BIT_WIDTH = 4,
    parameter CLK_FREQ = 50_000_000,    // Clock frequency in Hz
    parameter DEBOUNCE_TIME_MS = 20     // Debounce time in milliseconds
) (
    input                  clk,        // System clock
    input                  rst_n,      // Active low reset
    input  [BIT_WIDTH-1:0] button_in,  // Raw button input (noisy)
    output [BIT_WIDTH-1:0] button_out  // Debounced button output
);
  // Calculate counter value for debounce time
  localparam DEBOUNCE_FREQ = 1000 / DEBOUNCE_TIME_MS;

  wire clk_div;
  reg [BIT_WIDTH-1:0] button_sync_0, button_sync_1;

  clock_divider #(
      .CLK_FREQ(CLK_FREQ),
      .NEW_CLK_FREQ(DEBOUNCE_FREQ)
  ) clock_divider (
      .clk(clk),
      .rst_n(rst_n),
      .clk_div(clk_div)
  );

  assign button_out = button_sync_1;

  // Double-flop synchronizer to avoid metastability
  always @(posedge clk_div or negedge rst_n) begin
    if (!rst_n) begin
      button_sync_0 <= 0;
      button_sync_1 <= 0;
    end else begin
      button_sync_0 <= button_in;
      button_sync_1 <= button_sync_0;
    end
  end

endmodule
