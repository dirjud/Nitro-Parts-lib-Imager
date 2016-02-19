`include "terminals_defs.v"
`include "dtypes.v"
// Author: Lane Brooks
// Date: December 12, 2015

module overlay2
  #(parameter DIM_WIDTH=11)
   (
    input 			  clk,
    input 			  resetb,
    input 			  enable,

    input [DIM_WIDTH-1:0] 	  col_start,
    input [DIM_WIDTH-1:0] 	  row_start,
    input [DIM_WIDTH-1:0] 	  num_overlay_rows,
    input [DIM_WIDTH-1:0] 	  num_overlay_cols,
    input [31:0] 		  overlay_data,
    output 			  overlay_adv,
    output reg 			  overlay_restart,
    
    input 			  dvi,
    input [`DTYPE_WIDTH-1:0] 	  dtypei,
    input [7:0] 		  data0i,
    input [7:0] 		  data1i,
    input [7:0] 		  data2i,
    input [15:0] 		  meta_datai,
    
    output reg 			  dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo,
    output reg [7:0] 		  data0o,
    output reg [7:0] 		  data1o,
    output reg [7:0] 		  data2o,
    output reg [15:0] 		  meta_datao
    );

   function [7:0] blend;
      input [7:0] x0; // base
      input [2:0] a0;
      input [7:0] x1; // overlay
      input [2:0] a1;
      reg [10:0] xalpha0, xalpha1, cum;
      
      begin	 
	 if(a0 == 0) begin
	    blend = x1;
	 end else if(a1 == 0) begin
	    blend = x0;
	 end else begin
	    xalpha0 = x0 * a0;
	    xalpha1 = x1 * a1;
	    cum = xalpha0 + xalpha1;
	    // since cum can't overflow, just return the MSBs
	    blend = cum[10:3];
	 end
      end
   endfunction

   reg [DIM_WIDTH-1:0] 	      row_pos, col_pos;
   wire [DIM_WIDTH-1:0]       next_row_pos = row_pos + 1;
   wire [DIM_WIDTH-1:0]       next_col_pos = col_pos + 1;

   wire [DIM_WIDTH-1:0] row_end = row_start + num_overlay_rows;
   wire [DIM_WIDTH-1:0] col_end = col_start + num_overlay_cols;
   reg adv;

   wire overlay_en =dvi && dtypei == `DTYPE_PIXEL && row_pos >= row_start && row_pos < row_end && col_pos >= col_start && col_pos < col_end && enable;
   assign overlay_adv =  overlay_en && adv;

   wire [15:0] overlay_data1 = adv ? overlay_data[31:16] : overlay_data[15:0];
   wire        overlay_sel = (overlay_data1 != 0) && overlay_en;

   reg [6:0]   y0;
   reg [2:0]   a0;
   reg [5:0]   u0,v0;
   
   always @(*) begin
      u0 = overlay_data[5:0];
      v0 = overlay_data[21:16];
      if(adv) begin
	 y0 = overlay_data[28:22];
	 a0 = overlay_data[31:29];
      end else begin
	 y0 = overlay_data[12:6];
	 a0 = overlay_data[15:13];
      end
   end
   wire [7:0] y1 = { y0, 1'b0 };
   wire [7:0] u1 = { u0, 2'b0 };
   wire [7:0] v1 = { v0, 2'b0 };
   wire [2:0] a1 = 3'd7 - a0;

   wire [7:0] y2 = blend(data0i, a1, y1, a0);
   wire [7:0] u2 = blend(data1i, a1, u1, a0);
   wire [7:0] v2 = blend(data2i, a1, v1, a0);

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
	 adv        <= 0;
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
	    adv        <= 0;
	 end else begin
	    if(dvi && dtypei == `DTYPE_FRAME_END) begin
	       overlay_restart <= 1;
	       adv  <= 0;
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
	    if(overlay_en) begin
	       adv     <= !adv;
	    end
	    data0o  <= (overlay_sel) ? y2 : data0i;
	    data1o  <= (overlay_sel) ? u2 : data1i;
	    data2o  <= (overlay_sel) ? v2 : data2i;
	 end
      end
   end
endmodule


