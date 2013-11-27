`include "dtypes.v"
// Author: Lane Brooks
// Date: November 4, 2013

// Desc: Performs a dot product: a0*b0 + a1*b1 + a2*b2.
// You must specify whether the a terms are signed or not using the 'SIGNED'
// parameter. You cannot mixed signed and unsigned multiplication.

module dot_product3
  #(parameter A_DATA_WIDTH=8,
    parameter B_DATA_WIDTH=9,
    parameter SIGNED=1
    )
  (
   input [A_DATA_WIDTH-1:0] a0,
   input [A_DATA_WIDTH-1:0] a1,
   input [A_DATA_WIDTH-1:0] a2,
   input [B_DATA_WIDTH-1:0] b0,
   input [B_DATA_WIDTH-1:0] b1,
   input [B_DATA_WIDTH-1:0] b2,
   output [A_DATA_WIDTH+B_DATA_WIDTH+1:0] y
   );

   parameter TOTAL_WIDTH = A_DATA_WIDTH + B_DATA_WIDTH;
   
   wire signed [A_DATA_WIDTH-1:0] a0_signed = a0;
   wire signed [A_DATA_WIDTH-1:0] a1_signed = a1;
   wire signed [A_DATA_WIDTH-1:0] a2_signed = a2;
   wire signed [B_DATA_WIDTH-1:0] b0_signed = b0;
   wire signed [B_DATA_WIDTH-1:0] b1_signed = b1;
   wire signed [B_DATA_WIDTH-1:0] b2_signed = b2;
   
   wire signed [TOTAL_WIDTH-1:0] mult0_signed = a0_signed * b0_signed;
   wire signed [TOTAL_WIDTH-1:0] mult1_signed = a1_signed * b1_signed;
   wire signed [TOTAL_WIDTH-1:0] mult2_signed = a2_signed * b2_signed;

   wire [TOTAL_WIDTH+1:0] accum_signed = { {2{mult0_signed[TOTAL_WIDTH-1]}}, mult0_signed } + 
			                 { {2{mult1_signed[TOTAL_WIDTH-1]}}, mult1_signed } + 
			                 { {2{mult2_signed[TOTAL_WIDTH-1]}}, mult2_signed };


   wire [TOTAL_WIDTH-1:0] mult0_unsigned = a0 * b0;
   wire [TOTAL_WIDTH-1:0] mult1_unsigned = a1 * b1;
   wire [TOTAL_WIDTH-1:0] mult2_unsigned = a2 * b2;


   wire [TOTAL_WIDTH+1:0] accum_unsigned = { 2'b0, mult0_unsigned } + 
			                   { 2'b0, mult1_unsigned } + 
			                   { 2'b0, mult2_unsigned };

   assign y = (SIGNED==1) ? accum_signed : accum_unsigned;

endmodule


