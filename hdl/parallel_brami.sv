`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)


// parallelized BRAM interface; share 1 port for two tasks (1 read, 1 write)
// GOAL: alternate address of a BRAM port between two sources;
// each source is never valid two cycles in a row.
// outputs directly connect to BRAM

module parallel_brami 
  #(parameter RAM_WIDTH = 16,
    parameter RAM_DEPTH = 320*240)
   
   (
    input wire 				 clk_in,
    input wire 				 rst_in,
    input wire 				 valid_wr_in,
    input wire [$clog2(RAM_DEPTH-1):0] 	 addr_wr_in,
    input wire [RAM_WIDTH-1:0] 		 data_wr_in,
    
    input wire 				 valid_rd_in,
    input wire [$clog2(RAM_DEPTH-1):0] 	 addr_rd_in,
    
    output logic [$clog2(RAM_DEPTH)-1:0] addr_br,
    output logic 			 we_br,
    output logic [RAM_WIDTH-1:0] 	 din_br,
    output logic 			 probe_state
   );

   // intention: if read valid comes in, pass that through first!
   // never a delay of more than 1 cycle for the write, and this way clock cycle count stays constant for the read.
   // still an additional clock cycle for read or write introduced.
   
   typedef enum {
		 WR_HELD
		 ,IDLE
		 } holder_state;
   holder_state state;

   logic [$clog2(RAM_DEPTH)-1:0] held_wr_addr;
   logic [RAM_WIDTH-1:0] 	  held_wr_data;
   
   always_ff @(posedge clk_in) begin
      if (rst_in) begin
	 state <= IDLE;
	 held_wr_addr <= 0;
	 held_wr_data <= 0;
	 addr_br <= 0;
	 we_br <= 0;
	 din_br <= 0;
      end else begin
	 case (state)
	   IDLE: begin
	      if (valid_rd_in) begin
		 // send read data immediately
		 addr_br <= addr_rd_in;
		 we_br <= 1'b0;
		 if (valid_wr_in) begin
		    // both came in at the same time; wait on wr data.
		    state <= WR_HELD;
		    held_wr_addr <= addr_wr_in;
		    held_wr_data <= data_wr_in;
		 end
	      end else if (valid_wr_in) begin
		 // wr valid and rd not, so send write data.
		 addr_br <= addr_wr_in;
		 din_br <= data_wr_in;
		 we_br <= 1'b1;
	      end else begin
		 we_br <= 1'b0; // if not transmitting, disable bogus writes
	      end
	   end
	   WR_HELD: begin
	      // disregard ready signals.
	      // this means both signals were high on previous cycle, so neither should be now
	      // BIG ASSUMPTION ALLOWING THIS: data never ready on consecutive cycles
	      addr_br <= held_wr_addr;
	      din_br <= held_wr_data;
	      we_br <= 1'b1;
	      state <= IDLE;
	   end
	   
	 endcase // case (state)
      end
   end
   

endmodule // parallel_brami

`default_nettype wire
