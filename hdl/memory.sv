`timescale 1ns / 1ps
`default_nettype none

module addrval
  #(
    parameter WIDTH = 240)
   (
    input wire row,
    input wire column,
    output logic valid,
	output logic addr,
	output logic [2:0] offset
   // your code here
	);
   logic rounded;
   logic unrounded;
   unrounded = (row * WIDTH + column);
   rounded  = ((row * WIDTH + column)>>4)>>4;
   assign addr = unrounded >> 4;
   assign offset = unrounded - rounded;
   assign valid = 1;
endmodule


`default_nettype wire

