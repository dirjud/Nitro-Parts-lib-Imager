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
    parameter DI_DATA_WIDTH=32,
    parameter NUM_ROWS_WIDTH=12,
    parameter NUM_COLS_WIDTH=12,
    parameter ACCUM_WIDTH=NUM_ROWS_WIDTH+NUM_COLS_WIDTH+PIXEL_WIDTH-2
    )
  (
   input 		      pixclk,
   input 		      resetb,

   // di interface
   input 		      di_clk,
   input [15:0] 	      di_term_addr,
   input [31:0] 	      di_reg_addr,
   input 		      di_read_mode,
   input 		      di_read_req,
   input 		      di_read,
   input 		      di_write_mode,
   input 		      di_write,
   input [DI_DATA_WIDTH-1:0]  di_reg_datai,

   output 		      di_read_rdy,
   output [DI_DATA_WIDTH-1:0] di_reg_datao,
   output 		      di_write_rdy,
   output [15:0] 	      di_transfer_status,
   output 		      di_en,

   input 		      dvi,
   input [`DTYPE_WIDTH-1:0]   dtypei,
   input [PIXEL_WIDTH-1:0]    datai,

   output reg 		      done,
   output reg 		      busy
   );

   reg [ACCUM_WIDTH-1:0] 			  image_accum00;
   reg [ACCUM_WIDTH-1:0] 			  image_accum01;
   reg [ACCUM_WIDTH-1:0] 			  image_accum10;
   reg [ACCUM_WIDTH-1:0] 			  image_accum11;
   reg [NUM_ROWS_WIDTH+NUM_COLS_WIDTH-3:0] 	  image_accum_count;
   

`include "ImageMeanTerminalInstance.v"   
   assign di_transfer_status = 0;
   assign di_write_rdy = 1;
   assign di_read_rdy = 1;
   assign di_reg_datao = ImageMeanTerminal_reg_datao;
   assign di_en = di_term_addr == `TERM_ImageMean;
   
   reg [ACCUM_WIDTH-1:0] 	  accum[0:3];
   wire [1:0] 			  accum_addr = { row[0], col[0] };
   reg [NUM_ROWS_WIDTH-1:0] 		  row;
   reg [NUM_COLS_WIDTH-1:0] 		  col;
   wire 			  valid_pixel = (col >= window_col_start) && (col < window_col_end) && (row >= window_row_start) && (row < window_row_end);
   reg [NUM_ROWS_WIDTH+NUM_COLS_WIDTH-3:0] pix_count;
   
   always @(posedge pixclk or negedge resetb) begin
      if(!resetb) begin
	 accum[0]   <= 0;
	 accum[1]   <= 0;
	 accum[2]   <= 0;
	 accum[3]   <= 0;
	 image_accum00    <= 0;
	 image_accum01    <= 0;
	 image_accum10    <= 0;
	 image_accum11    <= 0;
	 col        <= 0;
	 row        <= 0;
	 done       <= 0;
	 busy       <= 0;
	 pix_count  <= 0;
	 image_accum_count<= 0;
      end else begin
	 if(dvi) begin
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
	    end else if(|(dtypei & `DTYPE_PIXEL_MASK)) begin
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
	       if(row == window_row_end) begin
		  done <= 1;
	       end
	    end else begin
	       done <= 0;
	    end
	 end else begin
	    done <= 0;
	 end
	 
	 if (dvi && dtypei == `DTYPE_FRAME_START) begin
	    busy <= 1;
	 end else if(done) begin
	    busy <= 0;
	 end

	 if (done) begin
	    image_accum00 <= accum[0];
	    image_accum01 <= accum[1];
	    image_accum10 <= accum[2];
	    image_accum11 <= accum[3];
	    image_accum_count <= pix_count;
	 end	    
      end
   end
endmodule
