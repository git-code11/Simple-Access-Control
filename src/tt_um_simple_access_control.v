
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
  wire [7:0] input_code = ui_in[7:0];  // Input Code is the lower 4 bit of ui_in
  wire [2:0] status;  // Access grant status //RGB

  assign ui_out[2:0] = status;

  assign status = input_code == 7'd5 ? 3'b000 : 3'b100;

endmodule
