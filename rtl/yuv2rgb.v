`include "dtypes.v"
// Author: Lane Brooks
// Date: November 4, 2013

// Desc: Converts YUV data to RGB data. Assumes that YUV do not have
// offset added to them. If they have, you must subtract the offset
// prior to this module. 

module yuv2rgb
  #(parameter PIXEL_WIDTH=8)
  (
   input clk,
   input resetb,
   input enable,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [PIXEL_WIDTH-1:0] y,
   input [PIXEL_WIDTH-1:0] u,
   input [PIXEL_WIDTH-1:0] v,
   input [15:0] meta_datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [PIXEL_WIDTH-1:0] r,
   output reg [PIXEL_WIDTH-1:0] g,
   output reg [PIXEL_WIDTH-1:0] b,
   output reg [15:0] meta_datao
   
   );

   wire [PIXEL_WIDTH-1:0] r1 = clamp(dot_product(298,   0,  409));
   wire [PIXEL_WIDTH-1:0] g1 = clamp(dot_product(298, -99, -209));
   wire [PIXEL_WIDTH-1:0] b1 = clamp(dot_product(298, 519,    0));

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 r          <= 0;
	 g          <= 0;
	 b          <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         r          <= (enable) ? r1 : y;
         g          <= (enable) ? g1 : u;
         b          <= (enable) ? b1 : v;
	 meta_datao <= meta_datai;
      end
   end

   function [PIXEL_WIDTH+4:0] dot_product;
      // This function takes in 11b signed coefficients where the top
      // bit is the sign (2's complement), the next bits are integer
      // portion and the lower eight bits are fractional portion. In
      // other words, the integer coeficients are effectively divided
      // by 256.
      input signed [10:0] c0;
      input signed [10:0] c1;
      input signed [10:0] c2;

      reg signed [PIXEL_WIDTH+10:0] a0;
      reg signed [PIXEL_WIDTH+10:0] a1;
      reg signed [PIXEL_WIDTH+10:0] a2;
      reg signed [PIXEL_WIDTH+12:0] x1;
      begin
	 a0 = r * c0;
	 a1 = g * c1;
	 a2 = b * c2;
	 x1 = { {2{a0[PIXEL_WIDTH+10]}}, a0} +  // sign-extend
	      { {2{a1[PIXEL_WIDTH+10]}}, a1} + 
	      { {2{a2[PIXEL_WIDTH+10]}}, a2} + 
	      128; // add and round knowing divide by 256 is next. 128 is the rounding factor given the 8b fractional portion of the coefficient data
	 dot_product[PIXEL_WIDTH+4:0] = x1[PIXEL_WIDTH+12:8]; // divide by 256

      end
   endfunction
   
   function [PIXEL_WIDTH-1:0] clamp;
      input signed [PIXEL_WIDTH+4:0] x3;
      reg signed [PIXEL_WIDTH+4:0]   max_pixel;
      
      begin
	 max_pixel = { 5'b0, { PIXEL_WIDTH { 1'b1 }}};
	 
	 // check for overflow and clamp pixel if necessary
	 clamp[PIXEL_WIDTH-1:0] = (x3 > max_pixel) ? {PIXEL_WIDTH { 1'b1 }} :
				  (x3 < 0) ? { PIXEL_WIDTH { 1'b0 }} :
				  x3[PIXEL_WIDTH-1:0];
      end
   endfunction

endmodule


