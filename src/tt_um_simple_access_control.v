
module tt_um_simple_access_control (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  wire [3:0] row, col;
  wire [2:0] rgb_out;

  assign {col, row}  = ui_in[7:0];  // 4X4 keypad input

  assign ui_out[2:0] = rgb_out;  // RGB LED output


  simple_access_control access_control (
      .clk(clk),
      .rst(rst_n),
      .row(row),
      .col(col),
      .rgb_out(rgb_out)
  );

endmodule
