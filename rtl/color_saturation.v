`include "dtypes.v"
// Author: Lane Brooks
// Date: October 30, 2013

// Desc: 
// Suppose you want to apply the following color saturation matrix to
// RGB data:
//         [ 1+2*strength     -strength     -strength ]
//  Argb = [    -strength  1+2*strength     -strength ]
//         [    -strength     -strength  1+2*strength ]
//
// Then in the YUV space, the matrix is 
//         [ 1  -1.40*strength  -0.67*strength ]
//  Ayuv = [ 0    1+3*strength          0      ]
//         [ 0         0          1+3*strength ]
//
// With all the zeros, it is much more efficient to calculate the
// color saturation in the YUV domain. Only the Y term needs a dot
// product.  All the other terms are just a single multiply.
//
// The input 'strength' is an unsigned, all fractional bit coefficient that
// Determines how much the color saturation is increased.

module color_saturation
  #(parameter PIXEL_WIDTH=8,
    parameter STRENGTH_WIDTH=8
    )
  (
   input 			  clk,
   input 			  resetb,
   input 			  enable,

   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [PIXEL_WIDTH-1:0] 	  yi,
   input signed [PIXEL_WIDTH-1:0] ui,
   input signed [PIXEL_WIDTH-1:0] vi,
   input [15:0] 		  meta_datai,
   input [STRENGTH_WIDTH-1:0] 	  strength, //an unsigned, all fractional bit strength coefficient
   
   output reg 			  dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [PIXEL_WIDTH-1:0]   yo,
   output reg signed [PIXEL_WIDTH-1:0]   uo,
   output reg signed [PIXEL_WIDTH-1:0]   vo,
   output reg [15:0] 		  meta_datao
   
   );

   
   // First caculate the update Y term using a dot product. Since u and v
   // are signed, we will need to convert y to a signed number as well, which
   // requires growing the y, u, and v terms by one bit.
   
   parameter COEFF_WIDTH=8;// 1 sign bit, 1 integer bit, & rest fractional bits
   wire signed [COEFF_WIDTH-1:0] b0 = 64;
   wire signed [COEFF_WIDTH-1:0] b1 = 89;  //equiv. to 1.391, 1% quant. error
   wire signed [COEFF_WIDTH-1:0] b2 = 43;  //equiv. to 0.672, .2% quant. error 
   
   wire signed [STRENGTH_WIDTH+COEFF_WIDTH-1:0] bs0 = { b0, { STRENGTH_WIDTH { 1'b0 }}};
   wire signed [STRENGTH_WIDTH+COEFF_WIDTH-1:0] bs1 = b1 * strength;
   wire signed [STRENGTH_WIDTH+COEFF_WIDTH-1:0] bs2 = b2 * strength;
   
   parameter TOTAL_WIDTH = PIXEL_WIDTH+STRENGTH_WIDTH+COEFF_WIDTH+1;
   parameter PIXEL_STRENGTH_WIDTH = PIXEL_WIDTH + STRENGTH_WIDTH;
   wire signed [TOTAL_WIDTH+1:0] 		y0;
   
   dot_product3minus #(.A_DATA_WIDTH(PIXEL_WIDTH+1),
		       .B_DATA_WIDTH(STRENGTH_WIDTH+COEFF_WIDTH), // two integer bits and 6 fractional bits
		       .SIGNED(1))
   y_dot_product
     (.a0( {              1'b0, yi } ), // use an extra bit to turn y signed
      .a1( { ui[PIXEL_WIDTH-1], ui } ),
      .a2( { vi[PIXEL_WIDTH-1], vi } ),
      .b0(bs0),
      .b1(bs1),
      .b2(bs2),
      .y(y0)
      );
   parameter Y_TOP_BIT = PIXEL_WIDTH+STRENGTH_WIDTH+COEFF_WIDTH-2;
   wire [PIXEL_WIDTH-1:0] y1 = /*y0[TOTAL_WIDTH+1] ? 0 : // check if it is negative and clamp to zero if it is */
			       |y0[TOTAL_WIDTH:Y_TOP_BIT] ? { PIXEL_WIDTH { 1'b1 }} :
			       y0[Y_TOP_BIT-1:Y_TOP_BIT-PIXEL_WIDTH];
   
   // Calculate u and v terms as 3*strength + 1.0
   wire [STRENGTH_WIDTH+1:0] uv_coeff0 = (3 * strength);
   wire [STRENGTH_WIDTH+1:0] uv_coeff1 = uv_coeff0 + { 2'b01, {STRENGTH_WIDTH{1'b0}}}; // add 1.0


   wire signed [STRENGTH_WIDTH+PIXEL_WIDTH+2:0] u0 = $signed(ui) * $signed({1'b0, uv_coeff1});
   wire signed [STRENGTH_WIDTH+PIXEL_WIDTH+2:0] v0 = $signed(vi) * $signed({1'b0, uv_coeff1});
   wire signed [PIXEL_WIDTH-1:0] u1, v1;
   
   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+3),
	   .DATAO_WIDTH(PIXEL_WIDTH),
	   .SIGNED(1))
   Uclamp(.xi(u0[PIXEL_WIDTH+STRENGTH_WIDTH+2:STRENGTH_WIDTH]),
	  .xo(u1));

   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+3),
	   .DATAO_WIDTH(PIXEL_WIDTH),
	   .SIGNED(1))
   Vclamp(.xi(v0[PIXEL_WIDTH+STRENGTH_WIDTH+2:STRENGTH_WIDTH]),
	  .xo(v1));
     

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
         yo         <= (enable) ? y1 : yi;
         uo         <= (enable) ? u1 : ui;
         vo         <= (enable) ? v1 : vi;
	 meta_datao <= meta_datai;
      end
   end

endmodule
