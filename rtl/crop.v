`include "dtypes.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date: 5/24/2018
// Desc: Takes in an image and center crops it

module crop
  #(parameter PIXEL_WIDTH=10,
    parameter DIM_WIDTH=12
    )
  (
   input 			 clk,
   input 			 resetb,
   input 			 enable,
   input [DIM_WIDTH-1:0] 	 num_output_rows,
   input [DIM_WIDTH-1:0] 	 num_output_cols,
   input 			 dvi,
   input [PIXEL_WIDTH-1:0] 	 datai,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [15:0] 		 meta_datai,

   output reg 			 dvo,
   output reg [PIXEL_WIDTH-1:0]  datao,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [15:0] 		 meta_datao
   );

   reg [DIM_WIDTH-1:0] 	       row, col, num_rows, num_cols;
   wire [DIM_WIDTH-1:0]        next_row = row + 1;
   wire [DIM_WIDTH-1:0]        next_col = col + 1;

   wire [DIM_WIDTH-1:0]        col_border = (num_cols - num_output_cols)/2;
   wire [DIM_WIDTH-1:0]        row_border = (num_rows - num_output_rows)/2;
   wire col_valid = (col >= col_border) && (col < (num_cols - col_border));
   wire row_valid = (row >= row_border) && (row < (num_rows - row_border));
   wire out_of_bounds = (num_rows > 0) && (num_cols > 0) && ((!col_valid) || (!row_valid));
   reg [5:0] header_addr;

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 datao  <= 0;
	 dtypeo <= 0;
	 meta_datao <= 0;

	 row <= 0;
	 col <= 0;
	 num_rows <= 0;
	 num_cols <= 0;
         header_addr <= 0;
         
      end else begin
	 datao  <= datai;

	 // adjust the image header to mark the smaller image
	 if(enable && dvi) begin
	    /* verilator lint_off WIDTH */
            if(header_addr == `Image_num_cols) begin
               meta_datao <= num_output_cols;
            end else if(header_addr == `Image_num_rows) begin
               meta_datao <= num_output_rows;
            end else begin
	       meta_datao <= meta_datai;
            end
	    /* verilator lint_on WIDTH */
	 end else begin
	    meta_datao <= meta_datai;
	 end


         
	 if(!enable) begin
	    num_rows <= 0;
	    num_cols <= 0;
	    dtypeo <= dtypei;
	    dvo <= dvi;

	 end else begin
            if((dvi && (|(dtypei & `DTYPE_PIXEL_MASK)) && out_of_bounds) ||
               (dvi && (dtypei == `DTYPE_ROW_START) && !row_valid) ||
               (dvi && (dtypei == `DTYPE_ROW_END) && !row_valid)
               ) begin
	       dtypeo <= 0;
	       dvo <= 0;
            end else begin
               dtypeo <= dtypei;
	       dvo <= dvi;
            end

	    if (dvi) begin
	       if (dtypei == `DTYPE_HEADER) begin
	          header_addr <= header_addr + 1;
	       end else if (dtypei == `DTYPE_HEADER_START) begin
	          header_addr <= 0;
	       end
	    end
	    if(dvi) begin
	       if(dtypei == `DTYPE_FRAME_START) begin
		  row <= 0;
		  col <= 0;
	       end else if(dtypei == `DTYPE_FRAME_END) begin
		  num_rows <= row;

	       end else if(dtypei == `DTYPE_ROW_END) begin
		  num_cols <= col;
		  col <= 0;
		  row <= next_row;
                  dtypeo <= dtypei;
	       end else if(dtypei == `DTYPE_PIXEL_MASK) begin
		  col <= next_col;
               end
	    end 


	 end
      end
   end

endmodule
