`include "dtypes.v"
// Author: Lane Brooks
// Date: Jan 5, 2016

// Desc: Applies a Color Correction Matrix (CCM) to RGB data input data.
//
// If input is a vector [ r g b ]
// and the CCM is:
// [ RR GR BR ]
// [ RG GG BG ]
// [ RB GB BB ]
//
// Then the output is RGB data equal to:
// [ r*RR+g*RG+b*RB r*GR+g*GG+b*GB r*BR+g*BG+b*BB ]
//
// The input is as assumed unsigned fixed width integers with a width
// of PIXEL_WIDTH. The output is identical.
//
// The CCM terms are signed fixed width integers of width COEFF_WIDTH
// and with COEFF_FRAC_WIDTH fractional bits. For example, if the
// COEFF_WIDTH=8 COEFF_FRAC_WIDTH=4, then to specify -0.5, you would
// take 0.5*16 = 8 or 0b00001000 and then invert that and add 1 to
// make it negative, which is 248 or 0b11111000.
//
module ccm
  #(parameter PIXEL_WIDTH=10,
    parameter COEFF_WIDTH=8,
    parameter COEFF_FRAC_WIDTH=5
    )
  (
   input 			  clk,
   input 			  resetb,
   input 			  enable,

   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [PIXEL_WIDTH-1:0] 	  ri,
   input [PIXEL_WIDTH-1:0] gi,
   input [PIXEL_WIDTH-1:0] bi,
   input [15:0] 		  meta_datai,
   input [COEFF_WIDTH-1:0] 	  RR,
   input [COEFF_WIDTH-1:0] 	  RG,
   input [COEFF_WIDTH-1:0] 	  RB,
   input [COEFF_WIDTH-1:0] 	  GR,
   input [COEFF_WIDTH-1:0] 	  GG,
   input [COEFF_WIDTH-1:0] 	  GB,
   input [COEFF_WIDTH-1:0] 	  BR,
   input [COEFF_WIDTH-1:0] 	  BG,
   input [COEFF_WIDTH-1:0] 	  BB,
   
   output reg 			  dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [PIXEL_WIDTH-1:0]   ro,
   output reg [PIXEL_WIDTH-1:0]   go,
   output reg [PIXEL_WIDTH-1:0]   bo,
   output reg [15:0] 		  meta_datao
   
   );

   parameter TOTAL_WIDTH = PIXEL_WIDTH + COEFF_WIDTH + 3;
   
   wire [TOTAL_WIDTH-1:0] r0, g0, b0;
   
   dot_product3 #(.A_DATA_WIDTH(PIXEL_WIDTH+1),//need to make it signed
		  .B_DATA_WIDTH(COEFF_WIDTH), 
		  .SIGNED(1))
   R_dot_product
     (.a0( { 1'b0, ri } ),
      .a1( { 1'b0, gi } ),
      .a2( { 1'b0, bi } ),
      .b0(RR),
      .b1(RG),
      .b2(RB),
      .y(r0)
      );
   dot_product3 #(.A_DATA_WIDTH(PIXEL_WIDTH+1),//need to make it signed
		  .B_DATA_WIDTH(COEFF_WIDTH), 
		  .SIGNED(1))
   G_dot_product
     (.a0( { 1'b0, ri } ),
      .a1( { 1'b0, gi } ),
      .a2( { 1'b0, bi } ),
      .b0(GR),
      .b1(GG),
      .b2(GB),
      .y(g0)
      );
   dot_product3 #(.A_DATA_WIDTH(PIXEL_WIDTH+1),//need to make it signed
		  .B_DATA_WIDTH(COEFF_WIDTH), 
		  .SIGNED(1))
   B_dot_product
     (.a0( { 1'b0, ri } ),
      .a1( { 1'b0, gi } ),
      .a2( { 1'b0, bi } ),
      .b0(BR),
      .b1(BG),
      .b2(BB),
      .y(b0)
      );

   function [PIXEL_WIDTH-1:0] sclamp;
      input [TOTAL_WIDTH-1:0] a;
      begin
	 sclamp = (a[TOTAL_WIDTH-1] == 1) ? 0 : // negative, so clamp to zero
		  (|a[TOTAL_WIDTH-1:TOTAL_WIDTH-COEFF_FRAC_WIDTH-1]) ? {PIXEL_WIDTH{1'b1}} : // overflow positive, so clamp to all 1's
		  a[TOTAL_WIDTH-COEFF_FRAC_WIDTH-2 : TOTAL_WIDTH-COEFF_FRAC_WIDTH-PIXEL_WIDTH-1];
      end
   endfunction

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 ro         <= 0;
	 ro         <= 0;
	 ro         <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         ro         <= (enable) ? sclamp(r0) : ri;
         go         <= (enable) ? sclamp(g0) : gi;
         bo         <= (enable) ? sclamp(b0) : bi;
	 meta_datao <= meta_datai;
      end
   end

endmodule
