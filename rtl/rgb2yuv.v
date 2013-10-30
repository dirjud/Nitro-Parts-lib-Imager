`include "terminals_defs.v"
`include "dtypes.v"
// Author: Lane Brooks
// Date: October 30, 2013

// Desc: Converts RGB data to YUV data. Y is converted as an unsigned
// number that spans the full range of the PIXEL_WIDTH. In other
// words, the offset of 16 is not added to the Y channel. This is so
// that later processing steps do not have to remove it prior to
// operating.  Furthermore, it also leaves U and V as signed numbers,
// which means it does not add the typical offset to it to make it an
// unsigned number. This is to make it easier for later processing
// steps that would typically have to first subtract the offset to
// make it signed prior to operating. This means that a final step
// before handing this YUV data off to something expecting more standard
// YUV data is to add the offsets to Y, U, and V channels.
//
// Really this implements a matrix multiply that leaves the Y channel
// as a signed number and the U and V channel as signed numbers.

module rgb2yuv
  #(parameter PIXEL_WIDTH=8)
  (
   input clk,
   input resetb,
   input enable,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [PIXEL_WIDTH-1:0] r,
   input [PIXEL_WIDTH-1:0] g,
   input [PIXEL_WIDTH-1:0] b,
   input [15:0] meta_datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [PIXEL_WIDTH-1:0] y,
   output reg [PIXEL_WIDTH-1:0] u,
   output reg [PIXEL_WIDTH-1:0] v,
   output reg [15:0] meta_datao
   
   );

   wire [PIXEL_WIDTH-1:0] y1 = unsigned_clamp(dot_product( 66, 129,  25));
   wire [PIXEL_WIDTH-1:0] u1 =   signed_clamp(dot_product(-38, -74, 112));
   wire [PIXEL_WIDTH-1:0] v1 =   signed_clamp(dot_product(112, -94, -18));
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 y          <= 0;
	 u          <= 0;
	 v          <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         y          <= (enable) ? y1 : r;
         u          <= (enable) ? u1 : g;
         v          <= (enable) ? v1 : b;
	 meta_datao <= meta_datai;
      end
   end

   function [PIXEL_WIDTH+2:0] dot_product;
      // This function takes in 9b signed coefficients where the top
      // bit is the sign (2's complement) and the lower eight bits are
      // fractional portion. In other words, the it divides the
      // integer coeficients it receives by 256.
      input signed [8:0] c0;
      input signed [8:0] c1;
      input signed [8:0] c2;

      reg signed [PIXEL_WIDTH+8:0]  a0;
      reg signed [PIXEL_WIDTH+8:0]  a1;
      reg signed [PIXEL_WIDTH+8:0]  a2;
      reg signed [PIXEL_WIDTH+10:0] x1;
      begin
	 a0 = r * c0;
	 a1 = g * c1;
	 a2 = b * c2;
	 x1 = {2'b0, a0} + {2'b0, a1} + {2'b0, a2} + 128; // add and round knowing divide by 256 is next. 128 is the rounding factor given the 8b coefficient data
	 dot_product[PIXEL_WIDTH+2:0] = x1[PIXEL_WIDTH+10:8]; // divide by 256

      end
   endfunction
   
   function [PIXEL_WIDTH-1:0] signed_clamp;
      input signed [PIXEL_WIDTH+2:0] x2;

      reg signed [PIXEL_WIDTH+2:0] min_value;
      reg signed [PIXEL_WIDTH+2:0] max_value;
      begin

	 // calculate the overflow thresholds
	 min_value = { 4'b1, {PIXEL_WIDTH-1 { 1'b0 }}};
	 max_value = { 4'b0, {PIXEL_WIDTH-1 { 1'b1 }}};

	 // check for overflow and clamp pixel if necessary
	 signed_clamp[PIXEL_WIDTH-1:0] = (x2 < min_value) ? min_value[PIXEL_WIDTH-1:0] :
					 (x2 > max_value) ? max_value[PIXEL_WIDTH-1:0] :

					x2[PIXEL_WIDTH-1:0];
      end
   endfunction

   function [PIXEL_WIDTH-1:0] unsigned_clamp;
      input [PIXEL_WIDTH+2:0] x3;
      begin
	 // check for overflow and clamp pixel if necessary
	 unsigned_clamp[PIXEL_WIDTH-1:0] = (|x3[PIXEL_WIDTH+2:PIXEL_WIDTH]) ? { PIXEL_WIDTH { 1'b1 }} :
					   x3[PIXEL_WIDTH-1:0];
      end
   endfunction

endmodule
