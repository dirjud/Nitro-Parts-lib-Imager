`include "dtypes.v"
`include "array.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date  : 12/15/2015

// Desc : The rgb2yuv module does not add the customary 128 to the U and V
// channels to keep them signed numbers. This module adds the customary 128 offset to make them more compliant.

module uv_offset
  #(parameter PIXEL_WIDTH=10,
    parameter DATA_WIDTH=16)
  (input clk,
   input 			 resetb,
   input 			 enable,
   
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 meta_datai,
   input [PIXEL_WIDTH-1:0] 	 yi,
   input [PIXEL_WIDTH-1:0] 	 ui,
   input [PIXEL_WIDTH-1:0] 	 vi,

   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 meta_datao,
   output reg [PIXEL_WIDTH-1:0]  yo,
   output reg [PIXEL_WIDTH-1:0]  uo,
   output reg [PIXEL_WIDTH-1:0]  vo
   );

   wire [PIXEL_WIDTH-1:0] 	 w128 = { 1'b1, {PIXEL_WIDTH-1 { 1'b0 }}};
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 yo         <= 0;
	 uo         <= 0;
	 vo         <= 0;	 
      end else begin
	 dvo        <= dvi        ;
	 dtypeo     <= dtypei     ;
	 meta_datao <= meta_datai ;
	 yo         <= yi         ;
	 uo         <= (enable) ? ui + w128 : ui;
	 vo         <= (enable) ? vi + w128 : vi;
      end
   end
endmodule
