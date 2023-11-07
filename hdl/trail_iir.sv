`timescale 1ns / 1ps
`default_nettype none

module trail_iir
  #(
    parameter Y_BITS = 4,
    parameter CB_BITS = 2,
    parameter CR_BITS = 2,
    parameter COLOR_DEPTH = 8, // should be sum of prev 3
    parameter THRESHOLD = 11
)
   (
    input wire clk_in,
    input wire rst_in,
    input wire [COLOR_DEPTH-1:0] history_in,
    input wire [COLOR_DEPTH-1:0] camera_in,
    output logic [COLOR_DEPTH-1:0] update_out
    );

   // implementation to come!
   // TOTAL CLOCK CYCLE LATENCY: 0
   // THROUGHPUT: 1/clk
   assign update_out = camera_in; // no iir, just camera

endmodule // trail_iir

`default_nettype wire
