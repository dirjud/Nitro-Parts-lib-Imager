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
// as an unsigned number and the U and V channel as signed numbers.

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


   wire [8:0] yR = 66;
   wire [8:0] yG = 129;
   wire [8:0] yB = 25;
   wire [8:0] uR = -38;
   wire [8:0] uG = -74;
   wire [8:0] uB = 112;
   wire [8:0] vR = 112;
   wire [8:0] vG = -94;
   wire [8:0] vB = -18;
   
   

// wire [PIXEL_WIDTH-1:0] y1 =unsigned_clamp(dot_product(66,129, 25, r, g, b));
// wire [PIXEL_WIDTH-1:0] u1 = signed_clamp(dot_product(112, 38, 74, b, r, g));
   wire [PIXEL_WIDTH-1:0] v1 = signed_clamp(dot_product(112, 94, 18, r, g, b));

   wire [PIXEL_WIDTH+10:0] y0;
   dot_product3
     #(.A_DATA_WIDTH(9),
       .B_DATA_WIDTH(PIXEL_WIDTH),
       .A_SIGNED(1),
       .B_SIGNED(0))
   Ydot_product
     (.a0(66),
      .a1(129),
      .a2(25),
      .b0(r),
      .b1(g),
      .b2(b),
      .y(y0)
      );
   wire [PIXEL_WIDTH+10:0] y0a = y0 + 128; // round
   wire [PIXEL_WIDTH-1:0]  y1;
   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+3),
   	   .DATAO_WIDTH(PIXEL_WIDTH),
   	   .SIGNED(1))
   Yclamp(.xi(y0a[PIXEL_WIDTH+10:8]), .xo(y1));
   //assign y1 = y0a[PIXEL_WIDTH+10:8];

   
   wire [PIXEL_WIDTH+10:0] u0;
   wire [PIXEL_WIDTH-1:0]  u1;
   dot_product3minus
     #(.A_DATA_WIDTH(9),
       .B_DATA_WIDTH(PIXEL_WIDTH),
       .A_SIGNED(1),
       .B_SIGNED(0))
   Udot_product
     (.a0(112),
      .a1(38),
      .a2(18),
      .b0(b),
      .b1(r),
      .b2(g),
      .y(u0)
      );
   wire signed [PIXEL_WIDTH+10:0] u0a = u0 + 128; // round
   //clamp #(.DATAI_WIDTH(PIXEL_WIDTH+3),
   //	   .DATAO_WIDTH(PIXEL_WIDTH),
   //	   .SIGNED(1))
   //Uclamp(.xi(u0a[PIXEL_WIDTH+10:8]), .xo(u1));
   assign u1 = u0a[PIXEL_WIDTH+7:8];
//   
//
//   wire [PIXEL_WIDTH+10:0] v0;
//   wire [PIXEL_WIDTH-1:0]  v1;
//   dot_product3
//     #(.A_DATA_WIDTH(9),
//       .B_DATA_WIDTH(PIXEL_WIDTH),
//       .A_SIGNED(1),
//       .B_SIGNED(0))
//   Vdot_product
//     (.a0(112),
//      .a1(-94),
//      .a2(-18),
//      .b0(r),
//      .b1(g),
//      .b2(b),
//      .y(v0)
//      );
//   wire signed [PIXEL_WIDTH+10:0] v0a = v0 + 128; // round
//   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+3),
//   	   .DATAO_WIDTH(PIXEL_WIDTH),
//   	   .SIGNED(1))
//   Vclamp(.xi(v0a[PIXEL_WIDTH+10:8]), .xo(v1));
//   //assign v1 = v0a[PIXEL_WIDTH+7:8];
   
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
      input unsigned [PIXEL_WIDTH:0] p0;
      input unsigned [PIXEL_WIDTH:0] p1;
      input unsigned [PIXEL_WIDTH:0] p2;

      reg signed [PIXEL_WIDTH+8:0]  a0;
      reg signed [PIXEL_WIDTH+8:0]  a1;
      reg signed [PIXEL_WIDTH+8:0]  a2;
      reg signed [PIXEL_WIDTH+10:0] x1;
      begin
	 a0 = p0 * c0;
	 a1 = p1 * c1;
	 a2 = p2 * c2;
	 x1 = { {2{a0[PIXEL_WIDTH+8]}}, a0} -  // sign-extend
	      { {2{a1[PIXEL_WIDTH+8]}}, a1} - 
	      { {2{a2[PIXEL_WIDTH+8]}}, a2};
// + 
//	      128; // add and round knowing divide by 256 is next. 128 is the rounding factor given the 8b coefficient data
	 dot_product[PIXEL_WIDTH+2:0] = x1[PIXEL_WIDTH+10:8]; // divide by 256

      end
   endfunction
   
   function signed [PIXEL_WIDTH-1:0] signed_clamp;
      input signed [PIXEL_WIDTH+2:0] x2;
      reg over_max;
      reg under_min;
      
      begin
	 over_max  = ((x2[PIXEL_WIDTH+2] == 0) &&  (|x2[PIXEL_WIDTH+1:PIXEL_WIDTH])) ? 1 : 0;
	 under_min = ((x2[PIXEL_WIDTH+2] == 1) && !(&x2[PIXEL_WIDTH+1:PIXEL_WIDTH])) ? 1 : 0; 

	 // check for overflow and clamp pixel if necessary
	 signed_clamp[PIXEL_WIDTH-1:0] = /*(over_max) ? { 1'b0, {PIXEL_WIDTH-1{1'b1}}} :
					 (under_min)? { 1'b1, {PIXEL_WIDTH-1{1'b0}}} : */
					 x2[PIXEL_WIDTH-1:0];
      end
   endfunction

endmodule


