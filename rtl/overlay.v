`include "terminals_defs.v"
`include "dtypes.v"
// Author: Lane Brooks
// Date: December 12, 2015

// Desc: Overlays an image over a di stream image. Works in either RGB
// or YUV space. The di image is the base and assumed to have no alpha
// channel, whereas the overlayed image must provide an alpha
// channel. The alpha for the base image, therefore, is set to the
// compliment of the overlaid image.
//
// 'row_start' and 'col_start' tell how to offset the overlay image. (0,0)
// would be the upper left.
//
// 'num_overlay_rows' and 'num_overlay_cols' tell how large the overlay
// image is. Unknown behavior will result if overlay image goes out of bounds
// of the base image.
//
// data0i, data1i, data2i are the base image input data, in either RGB
// or YUV format. Likewise data0o, data1o, data2o are the blended output stream.
//
// overlay0, overlay1, overlay2 are the overlay input stream. overlayA
// is the alpha channel dictating how to blend the
// overlay. Conceptually, if you consider overlayA as a purely
// fractional number, then the output for channel X would be:
//  dataXo <= (overlayX * overlayA) + (dataXi * (1-overlayA))
//
// This module strobes 'overlay_adv' to advance the overlay
// stream. The overlay stream must decide what to do if it does not
// have data ready. This module will strobe the 'overlay_restart' when
// it has completed overlaying and is ready to start over. Consider it
// a sync signal.
//
// This module does not sync its inputs, so if you change things in the
// middle of a frame you will likely get unexpected behavior.

module overlay
  #(parameter PIXEL_WIDTH=8,
    parameter ALPHA_WIDTH=8,
    parameter DATA_WIDTH=16,
    parameter DIM_WIDTH=11)
   (
    input 			  clk,
    input 			  resetb,
    input 			  enable,

    input [DIM_WIDTH-1:0] 	  col_start,
    input [DIM_WIDTH-1:0] 	  row_start,
    input [DIM_WIDTH-1:0] 	  num_overlay_rows,
    input [DIM_WIDTH-1:0] 	  num_overlay_cols,
    input [PIXEL_WIDTH-1:0] 	  overlay0,
    input [PIXEL_WIDTH-1:0] 	  overlay1,
    input [PIXEL_WIDTH-1:0] 	  overlay2,
    input [ALPHA_WIDTH-1:0] 	  overlayA,
    output 			  overlay_adv,
    output reg 			  overlay_restart,
    input [ALPHA_WIDTH-1:0] 	  global_alpha,
    
    input 			  dvi,
    input [`DTYPE_WIDTH-1:0] 	  dtypei,
    input [PIXEL_WIDTH-1:0] 	  data0i,
    input [PIXEL_WIDTH-1:0] 	  data1i,
    input [PIXEL_WIDTH-1:0] 	  data2i,
    input [DATA_WIDTH-1:0] 	  meta_datai,
    
    output reg 			  dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo,
    output reg [PIXEL_WIDTH-1:0]  data0o,
    output reg [PIXEL_WIDTH-1:0]  data1o,
    output reg [PIXEL_WIDTH-1:0]  data2o,
    output reg [DATA_WIDTH-1:0]   meta_datao
    );

   reg [DIM_WIDTH-1:0] 	      row_pos, col_pos;
   wire [DIM_WIDTH-1:0]       next_row_pos = row_pos + 1;
   wire [DIM_WIDTH-1:0]       next_col_pos = col_pos + 1;

   function [PIXEL_WIDTH-1:0] blend;
      input [PIXEL_WIDTH-1:0]   base;
      input [PIXEL_WIDTH-1:0] 	overlay;
      input [ALPHA_WIDTH-1:0] 	alpha;
      reg [ALPHA_WIDTH-1:0] 	alpha_compliment;
      reg [PIXEL_WIDTH+ALPHA_WIDTH-1:0] alpha_base, alpha_overlay, cum;
      begin
	 alpha_compliment = { ALPHA_WIDTH { 1'b1 }} - alpha;
	 
	 if(alpha == 0) begin
	    blend = base;
	 end else if(alpha_compliment == 0) begin
	    blend = overlay;
	 end else begin
	    alpha_base       = alpha_compliment * base;
	    alpha_overlay    = alpha * overlay;
	    cum              = alpha_base + alpha_overlay;
	    // since cum can't overflow, just return the MSBs
	    blend            = cum[PIXEL_WIDTH+ALPHA_WIDTH-1:ALPHA_WIDTH];
	 end
      end
   endfunction

   wire [DIM_WIDTH-1:0] row_end = row_start + num_overlay_rows;
   wire [DIM_WIDTH-1:0] col_end = col_start + num_overlay_cols;
   assign overlay_adv = dvi && dtypei == `DTYPE_PIXEL && row_pos >= row_start && row_pos < row_end && col_pos >= col_start && col_pos < col_end && enable;

   wire [2*ALPHA_WIDTH-1:0] overlayA1 = overlayA * global_alpha;
   wire [ALPHA_WIDTH-1:0]   overlayA2 = (&global_alpha) ? overlayA : overlayA1[2*ALPHA_WIDTH-1:ALPHA_WIDTH];

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 data0o     <= 0;
	 data1o     <= 0;
	 data2o     <= 0;
	 meta_datao <= 0;
	 row_pos    <= 0;
	 col_pos    <= 0;
	 overlay_restart <= 0;
      end else begin
	 if(!enable) begin
	    dvo        <= dvi        ;
	    dtypeo     <= dtypei     ;
	    data0o     <= data0i     ;
	    data1o     <= data1i     ;
	    data2o     <= data2i     ;
	    meta_datao <= meta_datai ;
	    row_pos    <= 0;
	    col_pos    <= 0;
	    overlay_restart <= 0;
	 end else begin
	    
	    if(dvi && dtypei == `DTYPE_FRAME_END) begin
	       overlay_restart <= 1;
	    end else begin
	       overlay_restart <= 0;
	    end

	    // calculate row and col position
	    if(dvi) begin
	       if(dtypei == `DTYPE_FRAME_START) begin
		  row_pos <= 0;
		  col_pos <= 0;
	       end else if(dtypei == `DTYPE_ROW_END) begin
		  row_pos <= next_row_pos;
		  col_pos <= 0;
	       end else if(dtypei == `DTYPE_PIXEL) begin
		  col_pos <= next_col_pos;
	       end
	    end

	    // calculate output stream
	    dvo        <= dvi;
	    dtypeo     <= dtypei;
	    meta_datao <= meta_datai;
	    if(overlay_adv) begin
	       data0o     <= blend(data0i,overlay0,overlayA2);
	       data1o     <= blend(data1i,overlay1,overlayA2);
	       data2o     <= blend(data2i,overlay2,overlayA2);
	    end else begin
	       data0o     <= data0i;
	       data1o     <= data1i;
	       data2o     <= data2i;
	    end
	 end
      end
   end
endmodule


