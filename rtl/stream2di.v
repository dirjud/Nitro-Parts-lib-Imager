// Author: Lane Brooks
// Date:   Jan 11, 2017
// Desc: Simulation model that buffers double imagers into ram and returns them
// over the di bus whenever read is called.
`include "dtypes.v"
`include "terminals_defs.v"

module stream2di
  #(parameter ADDR_WIDTH=22,
    parameter DI_DATA_WIDTH=32,
    parameter STREAM_DATA_WIDTH=16
    )
  (
   input 			 enable, // syncronous to rclk
   input 			 resetb,
   
   input 			 clki,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [STREAM_DATA_WIDTH-1:0] datai,

   input 			 rclk,
   input 			 di_read_mode,
   input 			 di_read,
   output reg 			 di_read_rdy,
   output [DI_DATA_WIDTH-1:0] 	 di_reg_datao
   );

   reg [31:0] 			  buffer[0:(1<<ADDR_WIDTH)-1][0:1];

   wire [31:0] buffer0_0 = buffer[0][0];
   wire [31:0] buffer1_0 = buffer[1][0];
   wire [31:0] buffer2_0 = buffer[2][0];
   wire [31:0] buffer3_0 = buffer[3][0];
   wire [31:0] buffer4_0 = buffer[4][0];
   wire [31:0] buffer5_0 = buffer[5][0];
   wire [31:0] buffer6_0 = buffer[6][0];
   wire [31:0] buffer7_0 = buffer[7][0];
   wire [31:0] buffer8_0 = buffer[8][0];
   wire [31:0] buffer9_0 = buffer[9][0];
   wire [31:0] buffer0_1 = buffer[0][1];
   wire [31:0] buffer1_1 = buffer[1][1];
   wire [31:0] buffer2_1 = buffer[2][1];
   wire [31:0] buffer3_1 = buffer[3][1];
   wire [31:0] buffer4_1 = buffer[4][1];
   wire [31:0] buffer5_1 = buffer[5][1];
   wire [31:0] buffer6_1 = buffer[6][1];
   wire [31:0] buffer7_1 = buffer[7][1];
   wire [31:0] buffer8_1 = buffer[8][1];
   wire [31:0] buffer9_1 = buffer[9][1];


   reg [ADDR_WIDTH-1:0] 	  waddr, raddr;
   reg 				  wbuf, rbuf;
   reg 				  phase;
   reg [15:0] 			  datai_s;

   reg [1:0] 			  wstate, rstate;
   parameter WIDLE=0, WCAPTURE=1;
   parameter RWAIT_FOR_BUFFER=0, READING=1;
   
   // Write Controller
   always @(posedge clki or negedge resetb) begin
      if(!resetb || !enable) begin
	 wstate <= WIDLE;
	 phase  <= 0;
	 wbuf   <= 0;
	 waddr  <= 0;
	 
      end else begin
	 if(wstate == WIDLE) begin
	    phase  <= 0;
	    waddr <= 0;
	    
	    if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       wstate <= WCAPTURE;
	    end
	    
	 end else if(wstate == WCAPTURE) begin

	    if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
	       phase <= !phase;
	       if(phase == 0) begin
		  datai_s <= datai;
	       end else begin
		  buffer[waddr][wbuf] <= { datai, datai_s };
		  waddr <= waddr + 1;
	       end

	    end else if(dvi && dtypei == `DTYPE_FRAME_END) begin
	       wstate <= WIDLE;
	       if(wbuf == rbuf) begin
		  wbuf <= !wbuf;
	       end
	    end
	 end
      end
   end

   // Read Controller
   assign di_reg_datao = buffer[raddr][rbuf];

   always @(posedge rclk or negedge resetb) begin
      if(!resetb || !enable) begin
	 raddr        <= 0;
	 rbuf         <= 0;
	 di_read_rdy  <= 0;
      end else begin

	 if(!enable) begin
	    rbuf <= 0;
	    raddr <= 0;
	    di_read_rdy <= 0;
	    
	 end else if(!di_read_mode) begin
	    di_read_rdy <= 0;
	    raddr <= 0;

	    if(rstate == READING) begin
	       rstate <= RWAIT_FOR_BUFFER;
	       rbuf <= !rbuf;
	    end
	    
	 end else begin
	    if(rstate == RWAIT_FOR_BUFFER) begin
	       if(rbuf != wbuf) begin
		  rstate <= READING;
	       end
	    end else if(rstate <= READING) begin
	       di_read_rdy <= 1;

	       if(di_read) begin
		  raddr <= raddr + 1;
	       end
	    end
	    
	 end
     
      end
   end
endmodule

