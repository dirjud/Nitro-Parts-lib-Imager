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

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo      <= 0;
	 dtypeo   <= 0;
	 datao    <= 0;
	 count    <= 0;
	 drop     <= 0;
      end else begin
	 // pass dtypeo & datao. We only control dvo to mask out dropped frames
	 dtypeo   <= dtypei;
	 datao    <= datai;

	 if(dvi && dtypei == `DTYPE_FRAME_START) begin
	    if(count == 0) begin // always pass frame 0
	       drop <= 0;
	       dvo  <= dvi;
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