`include "terminals_defs.v"
`include "dtypes.v"
// Author: Lane Brooks
// Date: November 1,, 2013

// Desc: Applies gain correction. The 'gain' is the amount of
// gain you want applied at the edge of the image to correct for lens
// vignetting.  This module will linearly scale the gain from 1.0 in
// the center of the image to 'gain' at the edge of the
// image. The 'gain' input can be viewed as the mantissa of a
// floating point number where all bits but the top one are
// fractional.  In other words, if GAIN_MANTISSA_WIDTH is 8, then a
// gain of 1 is 0x80. A gain of 1.5 is 0xC0. A gain of 0.5 is 0x40. To
// get gains of 2 or higher, use the 'gain_exponenet' input to specify
// how much the gain is to be left shifted. The gain for a given pixel
// is pro-rated by its distance from the center of the image. The gain
// at the center is hard-coded to 1.0. The edge of the image is
// assumed to be 2**(DIM_WIDTH-1). If your sensor does not have
// physical pixels at 2**(DIM_WIDTH-1), pre-scale your 'gain'
// input appropriately so that you acheive the desired gain at the
// physical edge of your sensor.

module vignette
  #(parameter PIXEL_WIDTH=8,
    parameter DIM_WIDTH=11,
    parameter GAIN_MANTISSA_WIDTH=8,
    parameter GAIN_EXPONENT_WIDTH=8)
   (
    input 			    clk,
    input 			    resetb,
    input 			    enable,
    
    input 			    dvi,
    input [`DTYPE_WIDTH-1:0] 	    dtypei,
    input [15:0] 		    datai,
    input [DIM_WIDTH-1:0] 	    num_cols,
    input [DIM_WIDTH-1:0] 	    num_rows,

    input [GAIN_MANTISSA_WIDTH-1:0] gain_mantissa,
    input [GAIN_EXPONENT_WIDTH-1:0] gain_exponent,
    
    output reg 			    dvo,
    output reg [`DTYPE_WIDTH-1:0]   dtypeo,
    output reg [15:0] 		    datao
    );

   reg [DIM_WIDTH-1:0] 	  col_pos;
   reg [DIM_WIDTH-1:0] 	  row_pos;

   wire valid_pixel = |(dtypei & `DTYPE_PIXEL_MASK);

   // Calculate distance from center of the image. Use the absolute
   // value instead of the true distance, which would require a square
   // root operation.
   wire [DIM_WIDTH-2:0] abs_delta_cols = abs_delta(col_pos, num_cols);
   wire [DIM_WIDTH-2:0] abs_delta_rows = abs_delta(row_pos, num_rows);
   wire [DIM_WIDTH-2:0] dist_from_center = (abs_delta_cols >> 1) + (abs_delta_rows >> 1);
   
   function [DIM_WIDTH-2:0] abs_delta;
      input [DIM_WIDTH-1:0]  pos;
      input [DIM_WIDTH-1:0]  total;
      reg signed [DIM_WIDTH-1:0] delta;
      reg [DIM_WIDTH-1:0] abs_delta1;
      reg [DIM_WIDTH-1:0] total_on_2;
      begin
	 total_on_2 = total >> 1;
	 /* verilator lint_off WIDTH */
	 delta = total_on_2 - pos;
	 /* verilator lint_on WIDTH */
	 abs_delta1 = (delta < 0) ? (~(delta)) + 1 : delta; // take absolute value
	 abs_delta = abs_delta1[DIM_WIDTH-2:0]; // drop the sign bit	 
      end
   endfunction

   // Now calculate the gain that needs applied at this position.
   wire [GAIN_MANTISSA_WIDTH-1:0] gain_of_1x = { 1'b1, { GAIN_MANTISSA_WIDTH-1 { 1'b0 }}};
   wire [GAIN_MANTISSA_WIDTH-1:0] gain_of_1x_normalized = gain_of_1x >> gain_exponent;
   wire [GAIN_MANTISSA_WIDTH-1:0] delta_gain = gain_mantissa - gain_of_1x_normalized;
   wire [GAIN_MANTISSA_WIDTH+DIM_WIDTH-2:0] position_delta_gain = delta_gain * dist_from_center;
   wire [GAIN_MANTISSA_WIDTH+DIM_WIDTH-2:0] gain_offset = { gain_of_1x_normalized, { DIM_WIDTH-1 { 1'b0 }}};
   wire [GAIN_MANTISSA_WIDTH+DIM_WIDTH-2:0] total_gain = position_delta_gain + gain_offset;
   parameter TOTAL_WIDTH = GAIN_MANTISSA_WIDTH + (DIM_WIDTH-1) + PIXEL_WIDTH;
   wire [TOTAL_WIDTH-1:0] datao1 = total_gain * datai;
   wire [TOTAL_WIDTH-1:0] datao2 = datao1 >> ((DIM_WIDTH-1) + (GAIN_MANTISSA_WIDTH-1) - gain_exponent);
   wire [PIXEL_WIDTH-1:0] datao_final = (|datao2[TOTAL_WIDTH-1:PIXEL_WIDTH]) ? { PIXEL_WIDTH {1'b1}} :
			  datao2[PIXEL_WIDTH-1:0];
   
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo    <= 0;
	 dtypeo <= 0;
	 datao  <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
	 if(dvi) begin
	    if (dtypei == `DTYPE_FRAME_START) begin
	       row_pos <= 0;
	    end else if (dtypei == `DTYPE_ROW_END) begin
	       row_pos <= row_pos + 1;
	    end
	    if (dtypei == `DTYPE_ROW_START) begin
	       col_pos <= 0;
	    end else if(valid_pixel) begin
	       col_pos <= col_pos + 1;
	    end
	 end
	 if(dvi && valid_pixel) begin
	    /* verilator lint_off WIDTH */
	    datao <= datao_final;
	    /* verilator lint_on WIDTH */
	 end else begin
	    datao <= datai;
	 end
      end
   end
endmodule


