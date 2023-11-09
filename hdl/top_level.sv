`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
		 input wire 	     clk_100mhz,
		 input wire [15:0]   sw, //all 16 input slide switches
		 input wire [3:0]    btn, //all four momentary button switches
		 output logic [15:0] led, //16 green output LEDs (located right above switches)
		 output logic [2:0]  rgb0, //rgb led
		 output logic [2:0]  rgb1 //rgb led
		 );

   parameter COLOR_DEPTH = 8;

   assign led = sw; //for debugging
   // //shut up those rgb LEDs (active high):
   // assign rgb1= 0;
   // assign rgb0 = 0;

   logic 			     sys_rst;
   assign sys_rst = btn[0];

   logic [COLOR_DEPTH-1:0] 	     history_pxl;
   logic [COLOR_DEPTH-1:0] 	     camera_pxl;
   logic [COLOR_DEPTH-1:0] 	     update_pxl;
   trail_iir #
     (.COLOR_DEPTH(COLOR_DEPTH)) 
   iir
       (
	.clk_in(clk_100mhz),
	.rst_in(sys_rst),
	.history_in(history_pxl),
	.camera_in(camera_pxl),
	.update_out(update_pxl)
	);
   
	


endmodule // top_level

`default_nettype wire
