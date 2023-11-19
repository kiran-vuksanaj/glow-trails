`timescale 1ns / 1ps
`default_nettype none

module scale(
	     input wire [1:0] 	 scale_in,
	     input wire [10:0] 	 hcount_in,
	     input wire [9:0] 	 vcount_in,
	     output logic [10:0] scaled_hcount_out,
	     output logic [9:0]  scaled_vcount_out,
	     output logic 	 valid_addr_out
	     );
   // your code here
   logic [10:0] 		 hcount2;
   logic [9:0] 			 vcount2;
   logic [10:0] 		 hcount4;
   assign hcount2 = hcount_in >>> 1;
   assign hcount4 = hcount_in >>> 2;
   assign vcount2 = vcount_in >>> 1;
   always_comb begin
      case ( scale_in )
	2'b00: begin
           scaled_hcount_out = hcount_in;
           scaled_vcount_out = vcount_in;
	end
	2'b10: begin
           scaled_hcount_out = hcount4;
           scaled_vcount_out = vcount2;
	end
	2'b11: begin
           scaled_hcount_out = hcount2;
           scaled_vcount_out = vcount2;
	end
	default: begin // not specified by spec, figure its good to define /something/
           scaled_hcount_out = hcount_in;
           scaled_vcount_out = vcount_in;
	end
      endcase
   end
   assign valid_addr_out = (scaled_hcount_out < 240 && scaled_vcount_out < 320);
endmodule


`default_nettype wire

