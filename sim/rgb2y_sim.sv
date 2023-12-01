`timescale 1ns / 1ps
`default_nettype none

module rgb2y_tb();

   logic clk_in;
   logic rst_in;
   logic [7:0] red_in;
   logic [7:0] green_in;
   logic [7:0] blue_in;
   logic [23:0] rgb_in;
   logic [7:0] y_out;

   assign red_in = rgb_in[23:16];
   assign green_in = rgb_in[15:8];
   assign blue_in = rgb_in[7:0];

   rgb_to_y utm
     (.clk_in(clk_in),
      .rst_in(rst_in),
      .red_in(red_in),
      .green_in(green_in),
      .blue_in(blue_in),
      .y_out(y_out)
      );
   
   
   always begin
      #5;
      clk_in = !clk_in;
   end
   
   
   initial begin
      $dumpfile("rgb2y.vcd");
      $dumpvars(0,rgb2y_tb);
      $display("Starting sim");

      clk_in = 0;
      rst_in = 0;
      #10;
      rst_in = 1;
      #10;
      rst_in = 0;
      #50;
      rgb_in = 24'hFFFFFF;
      #10;
      rgb_in = 24'h000000;
      #10;
      rgb_in = 24'hFA382D; // correct Y: 112
      #10;
      rgb_in = 24'h449923; // correct Y: 114
      #100;
      $display("finishing sim");
      $finish;
   end // initial begin

   
endmodule // rgb2y_tb



`default_nettype wire
