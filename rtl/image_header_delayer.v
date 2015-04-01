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

   reg [5:0] 			 waddr, raddr;
   reg 				 stalled;
   parameter FIFO_SIZE = `Image_image_data + 5;
   reg [`DTYPE_WIDTH + DATA_WIDTH - 1 : 0] fifo [0:FIFO_SIZE-1];
   
   always @(posedge clk) begin
      if(!resetb) begin
	 waddr   <= 0;
	 raddr   <= 0;
	 stalled <= 0;
	 datao   <= 0;
	 dvo     <= 0;
	 dtypeo  <= 0;
      end else begin
	 if(!enable) begin
	    dvo     <= dvi;
	    dtypeo  <= dtypei;
	    datao   <= datai;
	    stalled <= 0;

	 end else begin
	    if (dvi) begin
	       fifo[waddr] <= { dtypei, datai };
	       waddr <= (waddr == FIFO_SIZE-1) ? 0 : waddr + 1;
	    end
	    
	    if (!stalled) begin
	       if (raddr != waddr) begin
		  dvo <= 1;
		  { dtypeo, datao } <= fifo[raddr];
		  raddr <= (raddr == FIFO_SIZE-1) ? 0 : raddr + 1;
	       end else begin
		  dvo <= 0;
		  dtypeo <= 0;
		  datao <= 0;
	       end
	    end
	    
	    // maintain header address for correct image header substitution
	    if(dvi && dtypei == `DTYPE_HEADER_START) begin
	       stalled <= 1;
	    end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       stalled <= 0;
	    end
	 end
      end
   end

endmodule
