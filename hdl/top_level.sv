`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
		 input wire 	     clk_100mhz,
		 input wire [15:0]   sw, //all 16 input slide switches
		 input wire [3:0]    btn, //all four momentary button switches
		 output logic [15:0] led, //16 green output LEDs (located right above switches)
		 output logic [2:0]  rgb0, //rgb led
		 output logic [2:0]  rgb1, //rgb led
		 output logic [2:0]  hdmi_tx_p, //hdmi output signals (blue, green, red)
		 output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives)
		 output logic 	     hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
		 input wire [7:0]    pmoda,
		 input wire [2:0]    pmodb,
		 output logic 	     pmodbclk,
		 output logic 	     pmodblock,
		 input wire 	     uart_rxd,
		 output logic 	     uart_txd
		 );

   parameter COLOR_DEPTH = 12;

   // assign led = sw; //for debugging
   // //shut up those rgb LEDs (active high):
   // assign rgb1= 0;
   // assign rgb0 = 0;

   logic [7:0] 			     threshold;
   assign threshold = sw[15:8];
   

   logic 			     sys_rst;
   assign sys_rst = btn[0];

   // attempts to copy from lab 05
   //Clocking Variables:
   logic 			     clk_pixel, clk_5x, clk_camera; //clock lines (pixel clock and 1/2 tmds clock and camera clock)
   logic 			     locked; //locked signal (we'll leave unused but still hook it up)

   //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS,respectively
   // and also 192MHz, excess clock for reading ov5640 output
   cam_hdmi_clk_wiz mhdmicw 
     (
      .clk_pixel(clk_pixel),
      .clk_5x(clk_5x),
      .clk_cam(clk_camera),
      .reset(0),
      .locked(locked),
      .clk_in1(clk_100mhz)
      );
   
  // clock domain crossing: kiran style
   logic [2:0] pmodb_buf; // buffer, to make sure values only update on our clock domain!p
   logic [7:0] pmoda_buf;
   always_ff @(posedge clk_camera) begin
      pmoda_buf <= pmoda;
      pmodb_buf <= pmodb;
   end

   logic hsync_raw;
   logic hsync;
   logic vsync_raw;
   logic vsync;
   logic clk_rise; // prbly not necessary
   logic [15:0] data;
   logic 	valid_pixel;
    
   
   camera_bare cbm
     (.clk_pixel_in(clk_camera),
      .pclk_cam_in(pmodb_buf[0] ),
      .hs_cam_in(pmodb_buf[2]),
      .vs_cam_in(pmodb_buf[1]),
      .rst_in(sys_rst),
      .data_cam_in(pmoda_buf),
      .hs_cam_out(hsync_raw),
      .vs_cam_out(vsync_raw),
      .data_out(data),
      .valid_out(valid_pixel),
      .clk_rise(clk_rise)
      );

   assign vsync = vsync_raw; // invert here if hsync/vsync is wrong polarity!
   assign hsync = hsync_raw;
   
   
   logic 	valid_cc;
   logic [15:0] pixel_cc;
   logic [10:0] hcount_cc;
   logic [9:0] 	vcount_cc;

   camera_coord ccm
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .valid_in(valid_pixel),
      .data_in(data),
      .hsync_in(hsync),
      .vsync_in(vsync),
      .valid_out(valid_cc),
      .data_out(pixel_cc),
      .hcount_out(hcount_cc),
      .vcount_out(vcount_cc)
      );


   
   logic [16:0] memaddr_cam;
   assign memaddr_cam = hcount_cc + 320*vcount_cc;

   // pipeline of camera coord module output
   parameter PIPE_CC = 4;
   logic [16:0] memaddr_cam_pipe [PIPE_CC-1:0];
   logic [15:0] pixel_data_cc_pipe [PIPE_CC-1:0];
   logic 	data_valid_cc_pipe [PIPE_CC-1:0];

   always_ff @(posedge clk_camera) begin
      if (sys_rst) begin
	 memaddr_cam_pipe[0] <= 0;
	 pixel_data_cc_pipe[0] <= 0;
	 data_valid_cc_pipe[0] <= 0;
      end else begin
	 memaddr_cam_pipe[0] <= memaddr_cam;
	 pixel_data_cc_pipe[0] <= pixel_cc;
	 data_valid_cc_pipe[0] <= valid_cc;
	 for( int i=1; i<PIPE_CC; i+=1 ) begin
	    memaddr_cam_pipe[i] <= memaddr_cam_pipe[i-1];
	    pixel_data_cc_pipe[i] <= pixel_data_cc_pipe[i-1];
	    data_valid_cc_pipe[i] <= data_valid_cc_pipe[i-1];
	 end
      end // else: !if(sys_rst)
   end // always_ff @ (posedge clk_camera)
   
	 

   // trail iir algorithm; 
   logic [COLOR_DEPTH-1:0] history_pixel;
   logic [23:0] 	   history_pixel_full;
   assign history_pixel_full = {
				history_pixel[11:8],4'b0,
				history_pixel[7:4],4'b0,
				history_pixel[3:0],4'b0
				};

   logic [23:0] 	   camera_pixel_full;
   assign camera_pixel_full = {
			       pixel_data_cc_pipe[1][15:11], 3'b0,
			       pixel_data_cc_pipe[1][10:5], 2'b0,
			       pixel_data_cc_pipe[1][4:0], 3'b0
			       };

   logic [23:0] 	   update_pixel_full;
   logic [COLOR_DEPTH-1:0] update_pixel;
   assign update_pixel = {
			  update_pixel_full[23:20],
			  update_pixel_full[15:12],
			  update_pixel_full[7:4]
			  };
   
   logic 		   data_valid_iir;

   assign led[15:0] = (sw[0] ?
		      ( sw[1] ?
			update_pixel : pixel_data_cc_pipe[1] ) :
		       (sw[1] ?
			pixel_cc : data));
   

   
   trail_iir trail_generator
     (.clk_in(clk_camera),
      .rst_in(sys_rst),
      .threshold_in(threshold),
      .mask_in(sw[2]),
      .valid_in(data_valid_cc_pipe[1]),
      .history_in(history_pixel_full),
      .camera_in(camera_pixel_full),
      .update_out(update_pixel_full),
      .valid_out(data_valid_iir)
      );

			       


   // two port BRAM for IIR update; written data matches exactly between both BRAMs!
   // port B is wired to write iir output, port A is wired to read iir input, with proper clock delays
   xilinx_true_dual_port_read_first_2_clock_ram 
     #(.RAM_WIDTH(COLOR_DEPTH), // 8
       .RAM_DEPTH(320*240))
   frame_buffer_iir
     (// port a
      .addra(memaddr_cam),
      .clka(clk_camera),
      .wea(1'b0),
      .dina(),
      .ena(1'b1),
      .regcea(1'b1),
      .rsta(sys_rst),
      .douta(history_pixel),
      // port b
      .addrb(memaddr_cam_pipe[3]),
      .clkb(clk_camera),
      .web(data_valid_iir),
      .dinb(update_pixel),
      .enb(1'b1),
      .regceb(1'b1),
      .doutb()
      );

   
   //Signals related to driving the video pipeline
   logic [10:0] hcount_vsg; //horizontal count
   logic [9:0] 	vcount_vsg; //vertical count
   logic 	vert_sync; //vertical sync signal
   logic 	hor_sync; //horizontal sync signal
   logic 	active_draw; //active draw signal
   logic 	new_frame; //new frame (use this to trigger center of mass calculations)
   logic [5:0] 	frame_count; //current frame

   //output of the scaled modules
   logic [10:0] hcount_scaled; //scaled hcount for looking up camera frame pixel
   logic [9:0] 	vcount_scaled; //scaled vcount for looking up camera frame pixel
   logic 	valid_addr_scaled; //whether or not two values above are valid (or out of frame)   
   logic [16:0] img_addr_scaled;
   
   
   logic [1:0] 	valid_addr_scaled_pipe; //pipelining variables in || with frame_buffer


   // output of the memory read
   logic [COLOR_DEPTH-1:0] pixel_vsg_raw;
   logic [COLOR_DEPTH-1:0] pixel_vsg;

   
   // two port BRAM for VSG; written data matches exactly between both BRAMs!
   xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(COLOR_DEPTH), // 8
       .RAM_DEPTH(320*240))
   frame_buffer_vsg
     (//port a
      .addra(img_addr_scaled),
      .clka(clk_pixel),
      .dina(),
      .ena(valid_addr_scaled),
      .regcea(1'b1),
      .wea(1'b0),
      .douta(pixel_vsg_raw),
      .rsta(sys_rst),
      // port b
      .addrb(memaddr_cam_pipe[3]),
      .clkb(clk_camera),
      .web(data_valid_iir),
      .dinb(update_pixel),
      .enb(1'b1),
      .regceb(1'b1),
      .doutb()
      );

  //from week 04! (make sure you include in your hdl) (same as before)
  video_sig_gen mvg(
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount_vsg),
      .vcount_out(vcount_vsg),
      .vs_out(vert_sync),
      .hs_out(hor_sync),
      .ad_out(active_draw),
      .nf_out(new_frame),
      .fc_out(frame_count)
  );
   
   scale scale_m
     (
      .scale_in(sw[1:0]),
      .hcount_in(hcount_vsg),
      .vcount_in(vcount_vsg),
      .scaled_hcount_out(hcount_scaled),
      .scaled_vcount_out(vcount_scaled),
      .valid_addr_out(valid_addr_scaled)
      );
   assign img_addr_scaled = 320*vcount_scaled + hcount_scaled;

   // pipe valid addr timing!
   always_ff @(posedge clk_pixel)begin
      valid_addr_scaled_pipe[0] <= valid_addr_scaled;
      valid_addr_scaled_pipe[1] <= valid_addr_scaled_pipe[0];
   end

   assign pixel_vsg = valid_addr_scaled_pipe[1] ? pixel_vsg_raw : 0;

   logic [7:0] red;
   logic [7:0] green;
   logic [7:0] blue;
   
   assign red = {pixel_vsg[11:8],4'b0};
   assign green = {pixel_vsg[7:4],4'b0};
   assign blue = {pixel_vsg[3:0],4'b0};

   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!

   //three tmds_encoders (blue, green, red)
   tmds_encoder tmds_red
     (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(red),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[2]));

   tmds_encoder tmds_green
     (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(green),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[1]));

   tmds_encoder tmds_blue
     (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue),
      .control_in({vert_sync,hor_sync}),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[0]));

   //four tmds_serializers (blue, green, red, and clock)
   tmds_serializer red_ser
     (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[2]),
      .tmds_out(tmds_signal[2]));

   tmds_serializer green_ser
     (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[1]),
      .tmds_out(tmds_signal[1]));

   tmds_serializer blue_ser
     (
      .clk_pixel_in(clk_pixel),
      .clk_5x_in(clk_5x),
      .rst_in(sys_rst),
      .tmds_in(tmds_10b[0]),
      .tmds_out(tmds_signal[0]));

   //output buffers generating differential signal:
   OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
   OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
   OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
   OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));
   
   // manta!
   // manta manta_inst
   //   (.clk(clk_pixel),
   //    .rx(uart_rxd),
   //    .tx(uart_txd),
   //    .data_valid_rec(data_valid_rec),
   //    .memaddr_cam(memaddr_cam),
   //    .hcount_rec(hcount_rec),
   //    .vcount_rec(vcount_rec),
   //    .pixel_data_rec(pixel_data_rec),
   //    .memaddr_cam0(memaddr_cam_pipe[2]),
   //    .data_valid0(data_valid_rec_pipe[2]),
   //    .pixel_data0(pixel_data_rec_pipe[2])
   //    );


endmodule // top_level

`default_nettype wire
