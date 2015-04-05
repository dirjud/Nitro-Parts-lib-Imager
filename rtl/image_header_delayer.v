// Author: Lane Brooks
// Date: 3/31/2015
// Desc: Delays the image header until the start of the next frame and then
//  delays the next frame until the image header is clocked out. Put this
//  prior to the ancillary data sampler to make sure the ancillary data is
//  sampled synchronous to the frame that is being recorded.

`include "dtypes.v"
`include "terminals_defs.v"

module image_header_delayer
  #(parameter DATA_WIDTH=16
    )
  (
   input 			 resetb,

   input 			 clk,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 datai,
   input 			 enable,
   
   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 datao
   );

   reg [6:0] 			 waddr, raddr;
   reg 				 stalled1;

   // stall1 is used to delay the image header until the next frame start is
   // received. Then we release the image header. When the image header is
   // done, we then enter stall2 to give some time down time for anything
   // that may need some clocks cycles to close out the frame before sending
   // the next start of frame signal.
   
   parameter NUM_STALL2_COUNTS = 40;
   parameter FIFO_SIZE = `Image_image_data + 20 + NUM_STALL2_COUNTS;

   reg [`DTYPE_WIDTH + DATA_WIDTH - 1 : 0] fifo [0:FIFO_SIZE-1];

   reg  [5:0] stall2_count;
   wire [5:0] next_stall2_count = stall2_count - 1;
   wire       stalled2 = |stall2_count;

   wire [`DTYPE_WIDTH-1:0] dtype0;
   wire [DATA_WIDTH-1:0]   data0;

   assign { dtype0, data0 } = fifo[raddr];
   
   always @(posedge clk) begin
      if(!resetb) begin
	 waddr   <= 0;
	 raddr   <= 0;
	 stalled1<= 0;
	 stall2_count <= 0;
	 datao   <= 0;
	 dvo     <= 0;
	 dtypeo  <= 0;
      end else begin
	 if(!enable) begin
	    dvo     <= dvi;
	    dtypeo  <= dtypei;
	    datao   <= datai;
	    stalled1 <= 0;
	    stall2_count <= 0;

	 end else begin
	    if (dvi) begin
	       fifo[waddr] <= { dtypei, datai };
	       waddr <= (waddr == FIFO_SIZE-1) ? 0 : waddr + 1;
	    end
	    
	    if (!stalled1 && !stalled2) begin
	       if (raddr != waddr) begin
		  dvo <= 1;
		  datao <= data0;
		  dtypeo <= dtype0;
		  if(dtype0 == `DTYPE_HEADER_END) begin
		     stall2_count <= NUM_STALL2_COUNTS;
		  end else if(dtype0 == `DTYPE_ROW_END) begin
		     stall2_count <= 4;
		  end else if(dtype0 == `DTYPE_FRAME_START) begin
		     stall2_count <= 1;
		  end
		  raddr <= (raddr == FIFO_SIZE-1) ? 0 : raddr + 1;
	       end else begin
		  dvo <= 0;
		  dtypeo <= 0;
		  datao <= 0;
	       end
	    end else begin
	       dvo <= 0;
	       dtypeo <= 0;
	       datao <= 0;
	       if(stalled2) begin
		  stall2_count <= next_stall2_count;
	       end
	    end
	    
	    // maintain header address for correct image header substitution
	    if(dvi && dtypei == `DTYPE_HEADER_START) begin
	       stalled1 <= 1;
	    end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       stalled1 <= 0;
	    end
	 end
      end
   end

endmodule
