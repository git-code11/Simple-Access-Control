/**
* Clock Divider
*/

module clock_divider #(
    parameter CLK_FREQ = 50_000_000,    // Clock frequency in Hz
    parameter NEW_CLK_FREQ = 50     //  New Clock frequency in Hz
) (
    input clk,
    input rst_n,
    output reg clk_div
);
  // Calculate counter value for debounce time
  localparam COUNTER_MAX = CLK_FREQ / NEW_CLK_FREQ;
  localparam COUNTER_WIDTH = $clog2(COUNTER_MAX + 1);

  // Internal registers
  reg [COUNTER_WIDTH-1:0] counter;

  // debounce logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
      clk_div <= 0;
    end else begin
      if (counter >= counter_max) begin
        counter <= 0;
        clk_div <= ~clk_div;
      end else begin
        counter <= counter + 1;
      end
    end
  end

endmodule
