`timescale 1ns / 1ps
`default_nettype none

module trail_iir
  #(
    parameter Y_BITS = 4,
    parameter CB_BITS = 2,
    parameter CR_BITS = 2,
    parameter COLOR_DEPTH = 8, // should be sum of prev 3
    parameter THRESHOLD = 11,
    parameter DECAY = 32'b1111_1100_0000_0000_0000_0000_0000_0000
)
   (
    input wire 			   clk_in,
    input wire 			   rst_in,
    input wire 			   valid_in,
    input wire [COLOR_DEPTH-1:0]   history_in,
    input wire [COLOR_DEPTH-1:0]   camera_in,
    output logic [COLOR_DEPTH-1:0] update_out,
    output logic 		   valid_out
    );

   logic [31:0] 		   multiplier;
   assign multiplier = DECAY >> Y_BITS;
   
   // encoded {YYYYRRBB} for now
   logic [Y_BITS-1:0] 		   history_y;
   logic [CR_BITS-1:0] 		   history_cr;
   logic [CB_BITS-1:0] 		   history_cb;
   assign history_y = history_in[COLOR_DEPTH-1:COLOR_DEPTH-Y_BITS];
   assign history_cr = history_in[CB_BITS+CR_BITS-1:CB_BITS];
   assign history_cb = history_in[CB_BITS-1:0];

   logic [31:0] 		   y_decayed_32b;
   assign y_decayed_32b = (multiplier*history_y);

   logic [Y_BITS-1:0] 		   y_decayed;
   assign y_decayed = y_decayed_32b[31:32-Y_BITS];
   
   
   logic [COLOR_DEPTH-1:0] 	   history_decayed;
   assign history_decayed = { y_decayed, history_cr, history_cb }; // right now its just plain subtractin
   
   // implementation to come!
   // TOTAL CLOCK CYCLE LATENCY: 1
   // THROUGHPUT: 1/clk
   always_ff @(posedge clk_in) begin
      update_out <= (history_y > THRESHOLD) ? (history_decayed) : camera_in;
   end
   

endmodule // trail_iir

`default_nettype wire
