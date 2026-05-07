
`define default_netname none

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
  assign uio_oe = 0;
  assign uio_out = 0;
  assign uo_out[7:4] = 4'd0;

  wire _unused = &{uio_in, ui_in[7:5], ena, 1'b1};


  wire [4:0] keys = ui_in[4:0];  // 5 keys input from the keypad
  wire [2:0] rgb_out;
  wire is_unlocked;


  assign uo_out[2:0] = rgb_out;  // RGB LED output
  assign uo_out[3] = is_unlocked;  // Unlock indicator (e.g., a separate LED)

  simple_access_control access_control (
      .clk(clk),
      .rst_n(rst_n),
      .keys(keys),
      .rgb_out(rgb_out),
      .is_unlocked(is_unlocked)
  );
endmodule
