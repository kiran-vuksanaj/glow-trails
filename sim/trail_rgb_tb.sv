`timescale 1ns / 1ps
`default_nettype none

module trail_rgb_tb();

   logic clk_in;
   logic rst_in;
   logic valid_in;
   logic [23:0] history_in;
   logic [23:0] camera_in;
   logic [23:0] update_in;
   logic 	valid_out;

   trail_iir utm
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .valid_in(valid_in),
      .history_in(history_in),
      .camera_in(camera_in),
      .update_out(update_in),
      .valid_out(valid_out)
      );

   always begin
      #5;
      clk_in = !clk_in;
   end

   initial begin
      $dumpfile("trail.vcd");
      $dumpvars(0,trail_rgb_tb);
      $display("starting sim");

      // initial
      clk_in = 0;
      rst_in = 0;
      // reset signal
      #10;
      rst_in = 1;
      #10;
      rst_in = 0;
      #56;
      // test cases, sparse
      history_in = 24'h000000;
      camera_in = 24'h123456;
      valid_in = 1;
      #10;
      valid_in = 0;
      #50;
      
      history_in = 24'hFAF078;
      camera_in = 24'h123456;
      valid_in = 1;
      #10;
      valid_in = 0;
      #50;
      // test cases, dense
      history_in = 24'hFFEEDD;
      camera_in = 24'h543210;
      valid_in = 1;
      #10;
      history_in = 24'h543210;
      camera_in = 24'h654321;
      #10;
      history_in = 24'hEEEEEE;
      camera_in = 24'hFFFFFF;
      
      // finish
      #100;
      $display("ending sim");
      $finish;
      
      
   end // initial begin
   

endmodule // trail_rgb_tb

`default_nettype wire
