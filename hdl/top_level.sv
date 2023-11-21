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
		 output logic 	     pmodblock
		 );

   parameter COLOR_DEPTH = 8;

   assign led = sw; //for debugging
   // //shut up those rgb LEDs (active high):
   // assign rgb1= 0;
   // assign rgb0 = 0;

   logic 			     sys_rst;
   assign sys_rst = btn[0];

   // attempts to copy from lab 05
   //Clocking Variables:
   logic 			     clk_pixel, clk_5x; //clock lines (pixel clock and 1/2 tmds clock)
   logic 			     locked; //locked signal (we'll leave unused but still hook it up)

   //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS,respectively
   hdmi_clk_wiz_720p mhdmicw 
     (
      .clk_pixel(clk_pixel),
      .clk_tmds(clk_5x),
      .reset(0),
      .locked(locked),
      .clk_ref(clk_100mhz)
      );
   
   //camera module: (see datasheet)
   logic 			     cam_clk_buff, cam_clk_in; //returning camera clock
   logic 			     vsync_buff, vsync_in; //vsync signals from camera
   logic 			     href_buff, href_in; //href signals from camera
   logic [7:0] 			     pixel_buff, pixel_in; //pixel lines from camera
   logic [15:0] 		     cam_pixel; //16 bit 565 RGB image from camera
   logic 			     valid_pixel; //indicates valid pixel from camera
   logic 			     frame_done; //indicates completion of frame from camera

   //Clock domain crossing to synchronize the camera's clock

   //to be back on the [65MHz] 74.25MHz system clock, delayed by a clock cycle.
   always_ff @(posedge clk_pixel) begin
      cam_clk_buff <= pmodb[0]; //sync camera
      cam_clk_in <= cam_clk_buff;
      vsync_buff <= pmodb[1]; //sync vsync signal
      vsync_in <= vsync_buff;
      href_buff <= pmodb[2]; //sync href signal
      href_in <= href_buff;
      pixel_buff <= pmoda; //sync pixels
      pixel_in <= pixel_buff;
   end

  //Controls and Processes Camera information
  camera camera_m
    (
     .clk_pixel_in(clk_pixel),
     .pmodbclk(pmodbclk), //data lines in from camera
     .pmodblock(pmodblock), //
     //returned information from camera (raw):
     .cam_clk_in(cam_clk_in),
     .vsync_in(vsync_in),
     .href_in(href_in),
     .pixel_in(pixel_in),
     //output framed info from camera for processing:
     .pixel_out(cam_pixel), //16 bit 565 RGB pixel
     .pixel_valid_out(valid_pixel), //pixel valid signal
     .frame_done_out(frame_done) //single-cycle indicator of finished frame
     );
   
   //outputs of the recover module
   logic [15:0] pixel_data_rec; // pixel data from recovery module
   logic [10:0] hcount_rec; //hcount from recovery module
   logic [9:0] 	vcount_rec; //vcount from recovery module
   logic 	data_valid_rec; //single-cycle (74.25 MHz) valid data from recovery module

   //The recover module takes in information from the camera
   // and sends out:
   // * 5-6-5 pixels of camera information
   // * corresponding hcount and vcount for that pixel
   // * single-cycle valid indicator
   recover recover_m 
     (
      .valid_pixel_in(valid_pixel),
      .pixel_in(cam_pixel),
      .frame_done_in(frame_done),
      .system_clk_in(clk_pixel),
      .rst_in(sys_rst),
      .pixel_out(pixel_data_rec), //processed pixel data out
      .data_valid_out(data_valid_rec), //single-cycle valid indicator
      .hcount_out(hcount_rec), //corresponding hcount of camera pixel
      .vcount_out(vcount_rec) //corresponding vcount of camera pixel
      );
   logic 	data_valid_rec_pipe;
   always_ff @(posedge clk_pixel) begin
      data_valid_rec_pipe <= data_valid_rec;
   end
   

   logic [$clog2(320*240):0] memaddr_cam_pipe [5:0];
   logic [15:0]   pixel_data_rec_pipe [5:0];

   // RGB to YCrCb
   logic [7:0] 	r_in;
   assign r_in = {pixel_data_rec[15:11],3'b0};
   // assign r_in = {pixel_data_rec_pipe[2][15:11],3'b0};
   logic [7:0] 	g_in;
   assign g_in = {pixel_data_rec[10:5],2'b0};
   // assign g_in = {pixel_data_rec_pipe[2][10:5],2'b0};
   logic [7:0] 	b_in;
   assign b_in = {pixel_data_rec[4:0],3'b0};
   // assign b_in = {pixel_data_rec_pipe[2][4:0],3'b0};
   logic [9:0] 	y_out;
   logic [9:0] 	cr_out;
   logic [9:0] 	cb_out;
   rgb_to_ycrcb camera_cs_conv_m
     (.clk_in(clk_pixel),
      .r_in(r_in),
      .g_in(g_in),
      .b_in(b_in),
      .y_out(y_out),
      .cr_out(cr_out),
      .cb_out(cb_out)
      );
   logic [COLOR_DEPTH-1:0] camera_pxl;
   assign camera_pxl = {y_out[7:4], cr_out[7:6], cb_out[7:6]};
   
   // combinational logic hcount+vcount --> address
   logic [$clog2(320*240):0] memaddr_cam;
   assign memaddr_cam = hcount_rec + 320*vcount_rec;
   
   // pipeline for camera->memory addresses, camera data
   
   always_ff @(posedge clk_pixel) begin
      if (data_valid_rec) begin
	 memaddr_cam_pipe[0] <= memaddr_cam;
	 pixel_data_rec_pipe[0] <= camera_pxl;
	 for(int i=1; i<=5; i+=1) begin
	    memaddr_cam_pipe[i] <= memaddr_cam_pipe[i-1];
	    pixel_data_rec_pipe[i] <= pixel_data_rec_pipe[i-1];
	 end
      end
   end

   
   // IIR module
   logic [COLOR_DEPTH-1:0] history_pxl;
   logic [COLOR_DEPTH-1:0] update_pxl;
   logic 		   data_valid_iir;
   
   trail_iir #
     (.COLOR_DEPTH(COLOR_DEPTH)) 
   iir
     (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .history_in(history_pxl),
      .valid_in(data_valid_rec), // SUS
      .camera_in(camera_pxl),
      .update_out(update_pxl),
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
      .clka(clk_pixel),
      .wea(1'b0),
      .dina(),
      .ena(1'b1),
      .regcea(1'b1),
      .rsta(sys_rst),
      .douta(history_pxl),
      // port b
      .addrb(memaddr_cam_pipe[2]),
      .clkb(clk_pixel),
      .web(data_valid_iir),
      .dinb(update_pxl),
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

   //outputs of the rotation module
   logic [16:0] img_addr_rot; //result of image transformation rotation
   logic 	valid_addr_rot; //forward propagated valid_addr_scaled
   logic [1:0] 	valid_addr_rot_pipe; //pipelining variables in || with frame_buffer


   // output of the memory read
   logic [COLOR_DEPTH-1:0] pixel_vsg_raw;
   logic [COLOR_DEPTH-1:0] pixel_vsg;
   
   
   // two port BRAM for VSG; written data matches exactly between both BRAMs!
   xilinx_true_dual_port_read_first_2_clock_ram
     #(.RAM_WIDTH(COLOR_DEPTH), // 8
       .RAM_DEPTH(320*240))
   frame_buffer_vsg
     (//port a
      .addra(img_addr_rot),
      .clka(clk_pixel),
      .dina(),
      .ena(valid_addr_rot),
      .regcea(1'b1),
      .wea(1'b0),
      .douta(pixel_vsg_raw),
      .rsta(sys_rst),
      // port b
      .addrb(memaddr_cam),
      .clkb(clk_pixel),
      .web(data_valid_rec_pipe),
      .dinb(camera_pxl),
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
      .scale_in({sw[0],btn[1]}),
      .hcount_in(hcount_vsg),
      .vcount_in(vcount_vsg),
      .scaled_hcount_out(hcount_scaled),
      .scaled_vcount_out(vcount_scaled),
      .valid_addr_out(valid_addr_scaled)
      );


   //Rotates and mirror-images Image to render correctly (pi/2 CCW rotate):
   // The output address should be fed right into the frame buffer for lookup
   rotate rotate_m 
     (
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_in(hcount_scaled),
      .vcount_in(vcount_scaled),
      .valid_addr_in(valid_addr_scaled),
      .pixel_addr_out(img_addr_rot),
      .valid_addr_out(valid_addr_rot)
      );
   // pipe valid addr timing!
   always_ff @(posedge clk_pixel)begin
      valid_addr_rot_pipe[0] <= valid_addr_rot;
      valid_addr_rot_pipe[1] <= valid_addr_rot_pipe[0];
   end

   assign pixel_vsg = valid_addr_rot_pipe[1] ? pixel_vsg_raw : 0;

   logic [9:0] red_full;
   logic [9:0] green_full;
   logic [9:0] blue_full;
   logic [7:0] red;
   logic [7:0] green;
   logic [7:0] blue;
   
   
   ycrcb2rgb vsg_converter
     (.clk(clk_pixel),
      .ena(1'b1),
      .y( {pixel_vsg[7:4],4'b0} ),
      .cr( {pixel_vsg[3:2],6'b0} ),
      .cb( {pixel_vsg[1:0],6'b0} ),
      .r( red_full ),
      .g( green_full ),
      .b( blue_full )
      );
	  
   assign red = red_full[7:0];
   assign green = green_full[7:0];
   assign blue = blue_full[7:0];

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
   
      
   


endmodule // top_level

`default_nettype wire
