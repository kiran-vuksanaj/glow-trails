`timescale 1ns / 1ps
`default_nettype none

module iir_tb;

    //make logics for inputs and outputs!
    logic clk_in;
    logic rst_in;
    logic valid_in;
    logic [7:0] history_in;
    logic [7:0] camera_in;
    logic [7:0] update_out;
    logic valid_out;

    trail_iir uut(.clk_in(clk_in), 
						 .rst_in(rst_in),
                         .valid_in(valid_in),
                         .history_in(history_in),
                         .camera_in(camera_in),
                         .update_out(update_out),
                         .valid_out(valid_out));
    always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
    end

    //initial block...this is our test simulation
    initial begin
        $dumpfile("iir.vcd"); //file to store value change dump (vcd)
        $dumpvars(0,iir_tb); //store everything at the current level and below
        $display("Starting Sim"); //print nice message
        clk_in = 0; //initialize clk (super important)
        rst_in = 0; //initialize rst (super important)
        history_in = 7'b0;
        camera_in = 7'b0;
        valid_in = 0;
        tabulate_in = 0;
        #10  //wait a little bit of time at beginning
        rst_in = 1; //reset system
        #10; //hold high for a few clock cycles
        rst_in = 0;
        #10;
        for (int i = 0; i<1000; i= i+1)begin
          x_in = i;
          y_in = i/2;
          valid_in = 1;
          #10;
        end
        valid_in = 0;
        #100;
        tabulate_in = 1;
		#60;
		tabulate_in = 0;
        #10000;
		
		
		rst_in=0;
        #10;
        for (int i = 0; i<700; i= i+1)begin
          x_in = i;
          y_in = i;
          valid_in = 1;
          #10;
        end
        valid_in = 0;
        #100;
        tabulate_in = 1;
		#60;
		tabulate_in = 0;
        #10000;
		
		
		rst_in=0;
        #10;
        for (int i = 0; i<700; i= i+1)begin
          x_in = i;
          y_in = 10;
          valid_in = 1;
          #10;
        end
        valid_in = 0;
        #100;
        tabulate_in = 1;
		#60;
		tabulate_in = 0;
        #10000;
		
		rst_in=0;
        #10;
        for (int i = 0; i<700; i= i+1)begin
          x_in = i;
          y_in = 10;
          valid_in = i<11;
          #10;
        end
        valid_in = 0;
        #100;
        tabulate_in = 1;
		#60;
		tabulate_in = 0;
        #10000;
		
		

        $display("Finishing Sim"); //print nice message
        $finish;

    end
endmodule //counter_tb

`default_nettype wire