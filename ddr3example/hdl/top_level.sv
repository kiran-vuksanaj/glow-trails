`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Andrew Weinfeld, andrewj31415@gmail.com
// 
// Create Date: 11/10/2023 02:50:29 PM
// Design Name: 
// Module Name: top_level
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

  // Made by Andrew Weinfeld, andrewj31415@gmail.com
module top_level(
  // DDR3 ports
  inout   wire    [15:0]  ddr3_dq,
  inout   wire    [1:0]   ddr3_dqs_n,
  inout   wire    [1:0]   ddr3_dqs_p,
  output  wire    [12:0]  ddr3_addr,
  output  wire    [2:0]   ddr3_ba,
  output  wire            ddr3_ras_n,
  output  wire            ddr3_cas_n,
  output  wire            ddr3_we_n,
  output  wire            ddr3_reset_n,
  output  wire            ddr3_ck_p,
  output  wire            ddr3_ck_n,
  output  wire            ddr3_cke,
  output  wire    [1:0]   ddr3_dm,
  output  wire            ddr3_odt,
  
  // The usual ports
  input   wire    [15:0]  sw, //all 16 input slide switches
  input   wire    [3:0]   btn, //all four momentary button switches
  output  logic   [15:0]  led, //16 green output LEDs (located right above switches)
  output  logic   [2:0]   rgb0, //rgb led
  output  logic   [2:0]   rgb1, //rgb led
  output  logic   [6:0]   ss0_c,
  output  logic   [6:0]   ss1_c,
  output  logic   [3:0]   ss0_an,
  output  logic   [3:0]   ss1_an,
  input   wire            clk_100mhz
);
    
  localparam NUM_MAX = 10000;
    
  assign rgb1= 0;
  assign rgb0 = 0;
  
  logic [31:0] state;
  logic [31:0] cycle_counter;
  logic [31:0] num_to_write;
  logic [31:0] num_to_read;
  logic [31:0] latency_counter;
  logic [31:0] val_to_display;
  
  // user interface signals
  logic [26:0]      app_addr;
  logic [2:0]       app_cmd;
  logic             app_en;
  logic [127:0]     app_wdf_data;
  logic             app_wdf_end;
  logic             app_wdf_wren;
  logic [127:0]     app_rd_data;
  logic           app_rd_data_end;
  logic           app_rd_data_valid;
  logic           app_rdy;
  logic           app_wdf_rdy;
  logic           app_sr_req;
  logic           app_ref_req;
  logic           app_zq_req;
  logic           app_sr_active;
  logic           app_ref_ack;
  logic           app_zq_ack;
  logic           ui_clk;
  logic           ui_clk_sync_rst;
  logic [15:0]    app_wdf_mask;
  logic           init_calib_complete;
  logic [11:0]    device_temp;


  logic [15:0] sw_intermediate;
  logic [15:0] sw_sync;
  always_ff @(posedge ui_clk) begin // handle asynchronous switch toggles
    sw_intermediate <= sw;
    sw_sync <= sw_intermediate;
  end
  
  wire clk_100, clk_200;
  ddr3_clk ddr3_clk_inst (
    .clk_100(clk_100),
    .clk_200(clk_200),
    .clk_in1(clk_100mhz)
  );
  
  assign led[0] = 1'b1;
  assign led[1] = init_calib_complete;
  assign led[2] = cycle_counter[28];
  assign led[3] = app_rdy;
  assign led[15:4] = device_temp;

  logic btn0_deb;
  debouncer btn0_db (
    .clk_in(clk_200),
    .rst_in(btn[1]), // button 0 resets the system, button 1 resets the debouncer.
    .dirty_in(btn[0]),
    .clean_out(btn0_deb)
  );
  logic sys_rst_200, sys_rst_200_0, sys_rst_200_1;
  always_ff @(posedge clk_200) begin
    sys_rst_200_0 <= btn0_deb;
    sys_rst_200_1 <= sys_rst_200_0;
    sys_rst_200 <= sys_rst_200_1;
  end

  always_ff @(posedge ui_clk) begin
    if (ui_clk_sync_rst) begin
      cycle_counter <= 0;
    end else begin
      cycle_counter <= cycle_counter + 1;
    end
  end
  
  // Made by Andrew Weinfeld, andrewj31415@gmail.com
  always_ff @(posedge ui_clk) begin
    if (ui_clk_sync_rst) begin
      state <= 0;
    end else begin
      if (state == 0) begin
        state <= 1;
      end else if (state == 1) begin
        state <= 2;
        num_to_write <= 2;
      end else if (state == 2) begin
        if (app_wdf_rdy) begin
          state <= 3;
        end
      end else if (state == 3) begin
        if (app_rdy) begin
          if (num_to_write < NUM_MAX) begin
            state <= 2;
            num_to_write <= num_to_write + 1;
          end else begin
            state <= 4;
            num_to_read <= 2;
          end
        end
      end else if (state == 4) begin
        if (app_rdy) begin
          state <= 5;
        end
      end else if (state == 5) begin
        if (app_rd_data_valid) begin
          if (app_rd_data == 0) begin // not prime
            state <= 4;
            num_to_read <= num_to_read + 1;
          end else begin // prime!
            state <= 6;
            num_to_write <= num_to_read * 2;
          end
        end
      end else if (state == 6) begin
        if (app_wdf_rdy) begin
          state <= 7;
        end
      end else if (state == 7) begin
        if (app_rdy) begin
          if (num_to_write < NUM_MAX) begin
            num_to_write <= num_to_write + num_to_read;
            state <= 6;
          end else if (num_to_read < NUM_MAX) begin
            state <= 4;
            num_to_read <= num_to_read + 1;
          end else begin
            state <= 8;
            num_to_read <= 1;
          end
        end
      end else if (state == 8) begin
        if ((cycle_counter[23:0] == 0) && !sw_sync[0]) begin
          state <= 9;
          latency_counter <= 0;
          if (num_to_read >= NUM_MAX) begin
            num_to_read <= 2;
          end else begin
            num_to_read <= num_to_read + 1;
          end
        end else if (sw_sync[1]) begin
          num_to_read <= 2;
        end
      end else if (state == 9) begin
        latency_counter <= latency_counter + 1;
        if (app_rdy) begin
          state <= 10;
        end
      end else if (state == 10) begin
        latency_counter <= latency_counter + 1;
        if (app_rd_data_valid) begin
          if (app_rd_data == 0) begin
            state <= 9;
            if (num_to_read >= NUM_MAX) begin
              num_to_read <= 2;
            end else begin
              num_to_read <= num_to_read + 1;
            end
          end else begin
            state <= 8;
          end
        end
      end
    end
  end

  assign app_sr_req = 0;    // We aren't using these signals.
  assign app_ref_req = 0;
  assign app_zq_req = 0;
  always_comb begin   // Made by Andrew Weinfeld, andrewj31415@gmail.com
    if (state == 0) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 1) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 2) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = num_to_write;
      app_wdf_end = 1;
      app_wdf_wren = 1;
      app_wdf_mask = 0;
    end else if (state == 3) begin
      app_addr = num_to_write << 8;
      app_cmd = 0;
      app_en = 1;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 4) begin
      app_addr = num_to_read << 8;
      app_cmd = 1;
      app_en = 1;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 5) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 6) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 1;
      app_wdf_wren = 1;
      app_wdf_mask = 0;
    end else if (state == 7) begin
      app_addr = num_to_write << 8;
      app_cmd = 0;
      app_en = 1;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 8) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 9) begin
      app_addr = num_to_read << 8;
      app_cmd = 1;
      app_en = 1;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else if (state == 10) begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end else begin
      app_addr = 0;
      app_cmd = 0;
      app_en = 0;
      app_wdf_data = 0;
      app_wdf_end = 0;
      app_wdf_wren = 0;
      app_wdf_mask = 0;
    end
  end

  logic [16+(16-4)/3:0] bcd;
  logic [16+(16-4)/3:0] bcd2;
  bin2bcd#(.W(16)) bin2bcd_inst (
    .bin(num_to_read),
    .bcd(bcd)
  );
  bin2bcd#(.W(16)) bin2bcd_inst2 (
    .bin(latency_counter),
    .bcd(bcd2)
  );
  assign val_to_display = {bcd2[15:0], bcd[15:0]};

  logic [6:0] ss_c;
  seven_segment_controller mssc (
    .clk_in(ui_clk),
    .rst_in(ui_clk_sync_rst),
    .val_in(val_to_display),
    .cat_out(ss_c),
    .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c; //control upper four digit's cathodes!
  assign ss1_c = ss_c; //same as above but for lower four digits!
    
  ddr3_mig ddr3_mig_inst (
    .ddr3_dq(ddr3_dq),
    .ddr3_dqs_n(ddr3_dqs_n),
    .ddr3_dqs_p(ddr3_dqs_p),
    .ddr3_addr(ddr3_addr),
    .ddr3_ba(ddr3_ba),
    .ddr3_ras_n(ddr3_ras_n),
    .ddr3_cas_n(ddr3_cas_n),
    .ddr3_we_n(ddr3_we_n),
    .ddr3_reset_n(ddr3_reset_n),
    .ddr3_ck_p(ddr3_ck_p),
    .ddr3_ck_n(ddr3_ck_n),
    .ddr3_cke(ddr3_cke),
    .ddr3_dm(ddr3_dm),
    .ddr3_odt(ddr3_odt),
    .sys_clk_i(clk_200),
    .app_addr(app_addr),
    .app_cmd(app_cmd),
    .app_en(app_en),
    .app_wdf_data(app_wdf_data),
    .app_wdf_end(app_wdf_end),
    .app_wdf_wren(app_wdf_wren),
    .app_rd_data(app_rd_data),
    .app_rd_data_end(app_rd_data_end),
    .app_rd_data_valid(app_rd_data_valid),
    .app_rdy(app_rdy),
    .app_wdf_rdy(app_wdf_rdy), 
    .app_sr_req(app_sr_req),
    .app_ref_req(app_ref_req),
    .app_zq_req(app_zq_req),
    .app_sr_active(app_sr_active),
    .app_ref_ack(app_ref_ack),
    .app_zq_ack(app_zq_ack),
    .ui_clk(ui_clk), 
    .ui_clk_sync_rst(ui_clk_sync_rst),
    .app_wdf_mask(app_wdf_mask),
    .init_calib_complete(init_calib_complete),
    .device_temp(device_temp),
    .sys_rst(!sys_rst_200) // active low
  );

endmodule


    

module seven_segment_controller #(
  parameter COUNT_TO = 'd100_000
) (
  input   wire          clk_in,
  input   wire          rst_in,
  input   wire  [31:0]  val_in,
  output  logic [6:0]   cat_out,
  output  logic [7:0]   an_out
);
  logic [7:0]	  segment_state;
  logic [31:0]	segment_counter;
  logic [3:0]	  routed_vals;
  logic [6:0]	  led_out;

  bto7s mbto7s (.x_in(routed_vals), .s_out(led_out));
  assign cat_out = ~led_out; //<--note this inversion is needed
  assign an_out = ~segment_state; //note this inversion is needed
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      segment_state <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_TO) begin
        segment_counter <= 32'd0;
        segment_state <= {segment_state[6:0],segment_state[7]};
    	end else begin
    	  segment_counter <= segment_counter +1;
    	end
    end
  end
  // assign routed_vals = val_in >> (segment_state * 4);
  assign routed_vals = (segment_state[0] ? val_in[3:0] : 0)
                      | (segment_state[1] ? val_in[7:4] : 0)
                      | (segment_state[2] ? val_in[11:8] : 0)
                      | (segment_state[3] ? val_in[15:12] : 0)
                      | (segment_state[4] ? val_in[19:16] : 0)
                      | (segment_state[5] ? val_in[23:20] : 0)
                      | (segment_state[6] ? val_in[27:24] : 0)
                      | (segment_state[7] ? val_in[31:28] : 0);
endmodule // seven_segment_controller
 
/* TODO: drop your bto7s module from lab 1 here! */
module bto7s(input wire [3:0]   x_in,output logic [6:0] s_out);
  // array of bits that are "one hot" with numbers 0 through 15
        logic [15:0] num;
        assign num[0] = ~x_in[3] && ~x_in[2] && ~x_in[1] && ~x_in[0];
        assign num[1] = ~x_in[3] && ~x_in[2] && ~x_in[1] && x_in[0];
        assign num[2] = x_in == 4'd2;
        assign num[3] = x_in == 4'd3;
        assign num[4] = x_in == 4'd4;
        assign num[5] = x_in == 4'd5;
        assign num[6] = x_in == 4'd6;
        assign num[7] = x_in == 4'd7;
        assign num[8] = x_in == 4'd8;
        assign num[9] = x_in == 4'd9;
        assign num[10] = x_in == 4'd10;
        assign num[11] = x_in == 4'd11;
        assign num[12] = x_in == 4'd12;
        assign num[13] = x_in == 4'd13;
        assign num[14] = x_in == 4'd14;
        assign num[15] = x_in == 4'd15;
         
        assign s_out[0] =   num[4'h0]
                    | num[4'h2]
                    | num[4'h3]
                    | num[4'h5]
                    | num[4'h6]
                    | num[4'h7]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'ha]
                    | num[4'hc]
                    | num[4'he]
                    | num[4'hf]
                ;
        assign s_out[1] =   num[4'h0]
                    | num[4'h1]
                    | num[4'h2]
                    | num[4'h3]
                    | num[4'h4]
                    | num[4'h7]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'ha]
                    | num[4'hd]
                ;
        assign s_out[2] =   num[4'h0]
                    | num[4'h1]
                    | num[4'h3]
                    | num[4'h4]
                    | num[4'h5]
                    | num[4'h6]
                    | num[4'h7]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'ha]
                    | num[4'hb]
                    | num[4'hd]
                ;
        assign s_out[3] =   num[4'h0]
                    | num[4'h2]
                    | num[4'h3]
                    | num[4'h5]
                    | num[4'h6]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'hb]
                    | num[4'hc]
                    | num[4'hd]
                    | num[4'he]
                ;
        assign s_out[4] =   num[4'h0]
                    | num[4'h2]
                    | num[4'h6]
                    | num[4'h8]
                    | num[4'ha]
                    | num[4'hb]
                    | num[4'hc]
                    | num[4'hd]
                    | num[4'he]
                    | num[4'hf]
                ;
        assign s_out[5] =   num[4'h0]
                    | num[4'h4]
                    | num[4'h5]
                    | num[4'h6]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'ha]
                    | num[4'hb]
                    | num[4'hc]
                    | num[4'he]
                    | num[4'hf]
                ;
        assign s_out[6] =   num[4'h2]
                    | num[4'h3]
                    | num[4'h4]
                    | num[4'h5]
                    | num[4'h6]
                    | num[4'h8]
                    | num[4'h9]
                    | num[4'ha]
                    | num[4'hb]
                    | num[4'hd]
                    | num[4'he]
                    | num[4'hf]
                ;

endmodule // bto7s

// Taken from https://en.wikipedia.org/wiki/Double_dabble#Parametric_Verilog_implementation_of_the_double_dabble_binary_to_BCD_converter
module bin2bcd
 #( parameter                 W = 18)  // input width
  ( input  wire [W-1      :0] bin   ,  // binary
    output reg  [W+(W-4)/3:0] bcd   ); // bcd {...,thousands,hundreds,tens,ones}

  integer i,j;

  always_comb begin
    for(i = 0; i <= W+(W-4)/3; i = i+1) bcd[i] = 0;     // initialize with zeros
    bcd[W-1:0] = bin;                                   // initialize with input vector
    for(i = 0; i <= W-4; i = i+1)                       // iterate on structure depth
      for(j = 0; j <= i/3; j = j+1)                     // iterate on structure width
        if (bcd[W-i+4*j -: 4] > 4)                      // if > 4
          bcd[W-i+4*j -: 4] = bcd[W-i+4*j -: 4] + 4'd3; // add 3
  end

endmodule


//written in lab!
//debounce_2.sv is a different attempt at this done after class with a few students
module  debouncer #(
  parameter CLK_PERIOD_NS = 10,
  parameter DEBOUNCE_TIME_MS = 5
) (
  input wire clk_in,
  input wire rst_in,
  input wire dirty_in,
  output logic clean_out
);
  
  parameter COUNTER_MAX = int($ceil(DEBOUNCE_TIME_MS*1_000_000/CLK_PERIOD_NS));
  parameter COUNTER_SIZE = $clog2(COUNTER_MAX);
  logic [COUNTER_SIZE-1:0] counter;
  logic current; //register holds current output
  logic old_dirty_in;
  assign clean_out = current;

  always_ff @(posedge clk_in) begin
    if (rst_in)begin
      counter <= 0;
      current <= dirty_in;
      old_dirty_in <= dirty_in;
    end else begin
      if (counter == COUNTER_MAX-1)begin
        current <= old_dirty_in;
        counter <= 0;
      end else if (dirty_in == old_dirty_in) begin
        counter <= counter +1;
      end else begin
        counter <= 0;
      end
    end
    old_dirty_in <= dirty_in;
  end
endmodule

`default_nettype wire

