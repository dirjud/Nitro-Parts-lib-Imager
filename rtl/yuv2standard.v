`include "terminals_defs.v"
`include "dtypes.v"

/*
  module yuv2standard

  Simply adds an offset to u/v in order to create unsigned data.
  
 */

module yuv2standard
  #(parameter PIXEL_WIDTH=8)
  (
   input clk,
   input resetb,
   input enable,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [PIXEL_WIDTH-1:0] y,
   input signed [PIXEL_WIDTH-1:0] u,
   input signed [PIXEL_WIDTH-1:0] v,
   input [15:0] meta_datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [PIXEL_WIDTH-1:0] yo,
   output reg [PIXEL_WIDTH-1:0] uo,
   output reg [PIXEL_WIDTH-1:0] vo,
   output reg [15:0] meta_datao
   
   );

  always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 yo         <= 0;
	 uo         <= 0;
	 vo         <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         yo         <= (enable) ? y : y;
         uo         <= (enable) ? u+(128 << (PIXEL_WIDTH-8)) : u ;
         vo         <= (enable) ? v+(128 << (PIXEL_WIDTH-8)) : v ;
	 meta_datao <= meta_datai;
      end
   end
   

endmodule
