`include "dtypes.v"
// Author: Lane Brooks
// Date: 10/26/2013
// Desc: Implements KERNEL_SIZE row buffers and outputs a
// KERNEL_SIZE x KERNEL_SIZE output. For ease of implementation, this
// will drop a floor(KERNEL_SIZE/2) ring of pixels around the image.
// For exmaple, if KERNEL_SIZE is set to 3, this will output a 3x3
// kernel of the image and drop a 1 pixel ring around the image.

module ImageKernel
  #(parameter KERNEL_SIZE = 3,
    parameter DATA_WIDTH  = 8,
    parameter MAX_COLS    = 1288,
    parameter NUM_COLS_WIDTH = 11,
    parameter NUM_ROWS_WIDTH = 10
    )
  (input clk,
   input resetb,
   input enable,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [DATA_WIDTH-1:0] datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] datao[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1]
   );

   reg [DATA_WIDTH-1:0] rowbuf [0:MAX_COLS-1][0:KERNEL_SIZE-1];
   reg [NUM_COLS_WIDTH-1:0] col_addr, num_cols;
   reg [NUM_ROWS_WIDTH-1:0] row_addr;
      
   parameter BORDER_SIZE = KERNEL_SIZE/2
   wire valid_col = (col_addr > BORDER_SIZE) && (col_addr < num_cols - BORDER_SIZE); // drop border cols
   wire valid_row = row_addr > BORDER_SIZE; // drop border rows (don't need to worry about explicitely dropping the rows at the end of the image as that will happen automatically due to causality).
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 row_addr <= 0;
	 col_addr <= 0;
	 num_cols <= 0;
	 dtypeo   <= 0;
	 dvo      <= 0;
	 for (r1=0; r1<KERNEL_SIZE; r1=r1+1) begin
	    datao[r1][c1] <= 0;
	 end
	 
      end else begin
	 dtypeo <= dtypei;

	 if (dvi) begin
	    if (dtypei == `DTYPE_FRAME_START) begin
	       row_addr <= 0;
	       dvo <= 1;
	       
	    end else if (dtypei == `DTYPE_ROW_START) begin
	       col_addr <= 0;
	       dvo <= valid_row; // only start this row if it valid

	    end else if (dtypei == `DTYPE_ROW_END) begin
	       if(row_addr == 0) begin // record number of cols on first row
		  num_cols <= col_addr;
	       end
	       row_addr <= row_addr + 1;
	       dvo <= valid_row; // only end this row if it valid

	    end else if (dtypei & `DTYPE_PIXEL_MASK) begin
	       dvo <= valid_row && valid_col;
	       
	       col_addr <= col_addr + 1;
	       datao[KERNEL_SIZE-1][KERNEL_SIZE-1] <= datai;
	       for(r1=0; r1<KERNEL_SIZE; r1=r1+1) begin
		  for(c1=0; c1<KERNEL_SIZE-1; c1=c1+1) begin
		     datao[r1][c1] <= data[r1][c1+1];
		  end
	       end
	       for(r1=0; r1<KERNEL_SIZE-1; r1=r1+1) begin
		  rowbuf[col_addr][r1] <= datao[r1][0];
		  datao[r1][KERNEL_SIZE-1] <= rowbuf[col_addr][r1];
	       end
	    end else begin
	       dvo <= 1;
	    end
	 end else begin
	    dvo <= 0;
	 end
      end
   end
endmodule
