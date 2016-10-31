// Author: Lane Brooks
// Date: November 4, 2013

// Desc: Converts YUV data to RGB data. Assumes that YUV have
// offset added to them. 


function [PIXEL_WIDTH*3-1:0] yuv2rgb;
   input [PIXEL_WIDTH*3-1:0] yuv;
   reg [PIXEL_WIDTH-1:0] y1;
   reg [PIXEL_WIDTH-1:0] u1;
   reg [PIXEL_WIDTH-1:0] v1;
   reg [PIXEL_WIDTH:0] 	 u2;
   reg [PIXEL_WIDTH:0] 	 v2;
   reg [PIXEL_WIDTH-1:0] r1;
   reg [PIXEL_WIDTH-1:0] g1;
   reg [PIXEL_WIDTH-1:0] b1;
   begin
      v1 = yuv[3*PIXEL_WIDTH-1:2*PIXEL_WIDTH];
      u1 = yuv[2*PIXEL_WIDTH-1:1*PIXEL_WIDTH];
      y1 = yuv[PIXEL_WIDTH-1:0];
      u2 = u1 - {1'b1, {PIXEL_WIDTH-1{1'b0}}};
      v2 = v1 - {1'b1, {PIXEL_WIDTH-1{1'b0}}};
      r1 = clamp(dot_product(y1,u2,v2,298,   0,  409));
      g1 = clamp(dot_product(y1,u2,v2,298, -99, -209));
      b1 = clamp(dot_product(y1,u2,v2,298, 519,    0));
      yuv2rgb = { b1, g1, r1 };
   end
endfunction


function [PIXEL_WIDTH+4:0] dot_product;
   // This function takes in 11b signed coefficients where the top
   // bit is the sign (2's complement), the next bits are integer
   // portion and the lower eight bits are fractional portion. In
   // other words, the integer coeficients are effectively divided
   // by 256.
   input [PIXEL_WIDTH-1:0] yi;
   input signed [PIXEL_WIDTH:0] ui;
   input signed [PIXEL_WIDTH:0] vi;
   
   input signed [10:0] 		c0;
   input signed [10:0] 		c1;
   input signed [10:0] 		c2;
   
   reg signed [PIXEL_WIDTH+10:0] a0;
   reg signed [PIXEL_WIDTH+10:0] a1;
   reg signed [PIXEL_WIDTH+10:0] a2;
   reg signed [PIXEL_WIDTH+12:0] x1;
   begin
      a0 = yi * c0;
      a1 = ui * c1;
      a2 = vi * c2;
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

