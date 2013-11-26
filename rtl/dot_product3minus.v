`include "dtypes.v"
// Author: Lane Brooks
// Date: November 4, 2013

// Desc: Performs a dot product: a0*b0 + a1*b1 + a2*b2.
// You must specify whether the a terms are signed or not and likewise
// whether the b terms are signed or not by setting the 'A_SIGNED' and
// 'B_SIGNED' parameters.

module dot_product3minus
  #(parameter A_DATA_WIDTH=8,
    parameter B_DATA_WIDTH=9,
    parameter A_SIGNED=0,
    parameter B_SIGNED=1
    )
  (
   input [A_DATA_WIDTH-1:0] a0,
   input [A_DATA_WIDTH-1:0] a1,
   input [A_DATA_WIDTH-1:0] a2,
   input [B_DATA_WIDTH-1:0] b0,
   input [B_DATA_WIDTH-1:0] b1,
   input [B_DATA_WIDTH-1:0] b2,
   output reg [A_DATA_WIDTH+B_DATA_WIDTH+1:0] y
   );

   parameter TOTAL_WIDTH = A_DATA_WIDTH + B_DATA_WIDTH;
   
   wire signed [A_DATA_WIDTH-1:0] a0_signed = a0;
   wire signed [A_DATA_WIDTH-1:0] a1_signed = a1;
   wire signed [A_DATA_WIDTH-1:0] a2_signed = a2;
   wire signed [B_DATA_WIDTH-1:0] b0_signed = b0;
   wire signed [B_DATA_WIDTH-1:0] b1_signed = b1;
   wire signed [B_DATA_WIDTH-1:0] b2_signed = b2;
   
   reg signed [TOTAL_WIDTH-1:0] mult0_signed;
   reg signed [TOTAL_WIDTH-1:0] mult1_signed;
   reg signed [TOTAL_WIDTH-1:0] mult2_signed;
   wire [TOTAL_WIDTH-1:0]       mult0_unsigned = a0 * b0;
   wire [TOTAL_WIDTH-1:0]       mult1_unsigned = a1 * b1;
   wire [TOTAL_WIDTH-1:0]       mult2_unsigned = a2 * b2;

   always @(a0, a1, a2, b0, b1, b2, a0_signed, a1_signed, a2_signed, b0_signed, b1_signed, b2_signed) begin
      if(A_SIGNED == 1 && B_SIGNED == 0) begin
	 mult0_signed = a0_signed * b0;
	 mult1_signed = a1_signed * b1;
	 mult2_signed = a2_signed * b2;
      end else if(A_SIGNED == 0 && B_SIGNED == 1) begin
	 mult0_signed = a0 * b0_signed;
	 mult1_signed = a1 * b1_signed;
	 mult2_signed = a2 * b2_signed;
      end else begin
	 mult0_signed = a0_signed * b0_signed;
	 mult1_signed = a1_signed * b1_signed;
	 mult2_signed = a2_signed * b2_signed;
      end
   end

   wire [TOTAL_WIDTH+1:0] accum_unsigned = { 2'b0, mult0_unsigned } - 
			                   { 2'b0, mult1_unsigned } - 
			                   { 2'b0, mult2_unsigned };
   wire [TOTAL_WIDTH+1:0] accum_signed = { {2{mult0_signed[TOTAL_WIDTH-1]}}, mult0_signed } - 
			                 { {2{mult1_signed[TOTAL_WIDTH-1]}}, mult1_signed } - 
			                 { {2{mult2_signed[TOTAL_WIDTH-1]}}, mult2_signed };

   always @(mult0_unsigned,mult1_unsigned,mult2_unsigned,mult0_signed,mult1_signed,mult2_signed) begin
      if(A_SIGNED == 0 && B_SIGNED == 0) begin
	 y = accum_unsigned;
      end else begin
	 y = accum_signed;
      end
   end
endmodule


