// Frame downsampler drops frames from the image stream. The input
// parameter *downsample_amount* specifies the downsample rate. If it
// is set to 1, then no frames are dropped. If it is set to 2, then
// every other frame is dropped. If it is set to 3, then 2 out of
// every three frames are dropped, and so forth. Set
// *downsample_amount* to 0 or 1 to effectively disable this module.

`include "terminals_defs.v"
`include "dtypes.v"

module frame_downsampler
  #(DOWNSAMPLE_WIDTH=16)
  (input clk,
   input 			 resetb,

   input [DOWNSAMPLE_WIDTH-1:0] 		 downsample_amount,
   
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [15:0] 		 datai,

   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [15:0] 		 datao
   );

   reg 				 drop;
   reg  [DOWNSAMPLE_WIDTH-1:0]   count;
   wire [DOWNSAMPLE_WIDTH-1:0]   next_count = count + 1;
   reg [15:0] 			 frame_count;
   reg [5:0] 			 header_addr;
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo      <= 0;
	 dtypeo   <= 0;
	 datao    <= 0;
	 count    <= 0;
	 drop     <= 0;
	 frame_count <= 0;
	 header_addr <= 0;
      end else begin
	 // pass dtypeo & datao. We only control dvo to mask out dropped frames
	 dtypeo   <= dtypei;

	 if(dvi && dtypei == `DTYPE_HEADER_START) begin
	    header_addr <= 0;
	 end else if(dvi && dtypei == `DTYPE_HEADER) begin
	    header_addr <= header_addr + 1;
	 end
	 
	 if(header_addr == `Image_frame_count) begin
	    datao <= frame_count;
	 end else begin
	    datao <= datai;
	 end

	 if(dvi && dtypei == `DTYPE_FRAME_START) begin
	    if(count == 0) begin // always pass frame 0
	       drop <= 0;
	       dvo  <= dvi;
	       frame_count <= frame_count + 1;
	    end else begin // frames beyond 0
	       drop <= 1;
	       dvo  <= 0;
	    end
	    
	    // reset frame count when we reach the downsample_amount
	    if(next_count >= downsample_amount) begin
	       count <= 0;
	    end else begin
	       count <= next_count;
	    end

	 end else begin
	    if(drop) begin
	       dvo <= 0;
	    end else begin
	       dvo <= dvi;
	    end
	 end
      end
   end 

endmodule
