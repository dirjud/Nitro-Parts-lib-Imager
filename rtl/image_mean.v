`include "terminals_defs.v"
`include "dtypes.v"

/*
 module image_mean

 cumulates the image as four channels. Does not perform the final
 division to actually calculate the image mean. Assumes bayer data.
 Outputs accumulation of 
 */

module image_mean
  #(parameter PIXEL_WIDTH=8,
    parameter NUM_ROWS_WIDTH=12,
    parameter NUM_COLS_WIDTH=12,
    parameter ACCUM_WIDTH=NUM_ROWS_WIDTH+NUM_COLS_WIDTH+PIXEL_WIDTH-2
    )
  (
   input 			pixclk,
   input 			resetb,

   input 			dvi,
   input [`DTYPE_WIDTH-1:0] 	dtypei,
   input [PIXEL_WIDTH-1:0] 	datai,

   input [NUM_ROWS_WIDTH-1:0] 	row_start,
   input [NUM_ROWS_WIDTH-1:0] 	row_end,
   input [NUM_COLS_WIDTH-1:0] 	col_start,
   input [NUM_COLS_WIDTH-1:0] 	col_end,

   output reg [ACCUM_WIDTH-1:0] accum00,
   output reg [ACCUM_WIDTH-1:0] accum01,
   output reg [ACCUM_WIDTH-1:0] accum10,
   output reg [ACCUM_WIDTH-1:0] accum11,
   output reg [NUM_ROWS_WIDTH+NUM_COLS_WIDTH-1:0] accum_count,
   
   output reg 			done,
   output reg 			busy
   );

   reg [ACCUM_WIDTH-1:0] 	  accum[0:3];
   wire [1:0] 			  accum_addr = { row[0], col[0] };
   reg [NUM_ROWS_WIDTH-1:0] 		  row;
   reg [NUM_COLS_WIDTH-1:0] 		  col;
   wire 			  valid_pixel = (col >= col_start) && (col < col_end) && (row >= row_start) && (row < row_end);
   reg [NUM_ROWS_WIDTH+NUM_COLS_WIDTH-1:0] pix_count;
   
   always @(posedge pixclk or negedge resetb) begin
      if(!resetb) begin
	 accum[0]   <= 0;
	 accum[1]   <= 0;
	 accum[2]   <= 0;
	 accum[3]   <= 0;
	 accum00    <= 0;
	 accum01    <= 0;
	 accum10    <= 0;
	 accum11    <= 0;
	 col        <= 0;
	 row        <= 0;
	 done       <= 0;
	 busy       <= 0;
	 pix_count  <= 0;
	 accum_count<= 0;
      end else begin
	 if (dtypei == `DTYPE_FRAME_START) begin
	    accum[0] <= 0;
	    accum[1] <= 0;
	    accum[2] <= 0;
	    accum[3] <= 0;
	    row      <= 0;
	    col      <= 0;
	    pix_count<= 0;
	 end else if(dtypei == `DTYPE_ROW_END) begin
	    col      <= 0;
	    row      <= row + 1;
	 end else if(dtypei == `DTYPE_PIXEL_MASK) begin
	    col      <= col + 1;
	    if(valid_pixel) begin
	       /* verilator lint_off WIDTH */
	       accum[accum_addr] <= accum[accum_addr] + datai;
	       /* verilator lint_on WIDTH */
	       if(accum_addr == 0) begin
		  pix_count <= pix_count + 1;
	       end
	    end
	 end
	 
	 if(dtypei == `DTYPE_ROW_END) begin
	    if(row == row_end) begin
	       done <= 1;
	    end
	 end else begin
	    done <= 0;
	 end

	 if (dtypei == `DTYPE_FRAME_START) begin
	    busy <= 1;
	 end else if(done) begin
	    busy <= 0;
	 end

	 if (done) begin
	    accum00 <= accum[0];
	    accum01 <= accum[1];
	    accum10 <= accum[2];
	    accum11 <= accum[3];
	    accum_count <= pix_count;
	 end	    
      end
   end
endmodule
