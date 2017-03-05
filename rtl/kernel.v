`include "dtypes.v"
`include "array.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date: 10/26/2013

// Desc: Implements KERNEL_SIZE-1 row buffers and outputs a kernel
// sized (KERNEL_SIZE x KERNEL_SIZE). For ease of implementation, this
// will drop a KERNEL_SIZE-1 pixels from the rows and cols of the
// image.  For exmaple, if KERNEL_SIZE is set to 3, this will output a
// 3x3 kernel of the image and drop a 1 pixel ring around the
// image.

module kernel
  #(parameter KERNEL_SIZE = 3,
    parameter PIXEL_WIDTH = 10,
    parameter DATA_WIDTH  = 16,
    parameter MAX_COLS    = 1288,
    parameter NUM_COLS_WIDTH = 11
    )
  (input clk,
   input 					    resetb,

   input 					    dvi,
   input [`DTYPE_WIDTH-1:0] 			    dtypei,
   input [PIXEL_WIDTH-1:0] 			    datai,
   input [DATA_WIDTH-1:0] 			    meta_datai,
   input 					    enable,
   
   output reg 					    dvo,
   output reg [DATA_WIDTH-1:0] 			    meta_datao,
   output reg [`DTYPE_WIDTH-1:0] 		    dtypeo,
   output [KERNEL_SIZE*KERNEL_SIZE*PIXEL_WIDTH-1:0] kernel_datao
   );

   reg [PIXEL_WIDTH-1:0] datao [0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
`PACK_2DARRAY(pk_idx, PIXEL_WIDTH, KERNEL_SIZE, KERNEL_SIZE, datao, kernel_datao)

   reg [31:0] row, col;
   
   reg [NUM_COLS_WIDTH-1:0] col_addr;
   reg [KERNEL_SIZE-1:0] row_addr; // this should be a width of LOG2_KERNEL_SIZE

   parameter BORDER_SIZE = KERNEL_SIZE-1;
   /* verilator lint_off WIDTH */
   wire valid_col = col_addr >= BORDER_SIZE;
   wire valid_row = row_addr >= BORDER_SIZE;
   /* verilator lint_on WIDTH */

   reg [5:0] header_addr;


   reg [PIXEL_WIDTH-1:0] rowbufi[0:KERNEL_SIZE-2];
   wire [PIXEL_WIDTH-1:0] rowbufo[0:KERNEL_SIZE-2];

   wire we = dvi && |(dtypei & `DTYPE_PIXEL_MASK);
   
   genvar 		 x;
   
   generate
      for(x=0; x<KERNEL_SIZE-1; x=x+1) begin
	 rowbuffer #(.ADDR_WIDTH(NUM_COLS_WIDTH),
		     .MAX_COLS(MAX_COLS),
		     .PIXEL_WIDTH(PIXEL_WIDTH)
		     )
	 rowbuffer
	   (.addr(col_addr),
	    .we(we),
	    .clk(clk),
	    .datai(rowbufi[x]),
	    .datao(rowbufo[x])
	    );
      end
   endgenerate

   // Currently, the data in the rows moves from one row buffer to the next.
   // An alternative way to implement this is to only actively write into
   // one row buffer at a time and use pointer muxing to swap the buffers
   // around.
   always @(datai) begin
      rowbufi[KERNEL_SIZE-2] = datai[PIXEL_WIDTH-1:0];
   end
   generate
      for(x=0; x<KERNEL_SIZE-2; x=x+1) begin
	 always @(col_addr) begin
	    rowbufi[x] = rowbufo[x+1];
	 end
      end
   endgenerate

   always @(posedge clk) begin
      if(!resetb) begin
	 row_addr <= 0;
	 col_addr <= 0;
	 dtypeo   <= 0;
	 dvo      <= 0;
	 header_addr <= 0;
	 meta_datao <= 0;
	 for (row=0; row<KERNEL_SIZE; row=row+1) begin
	    datao[row][col] <= 0;
	 end
	 
      end else begin
	 dtypeo <= dtypei;

	 if (dvi) begin
	    if (!enable) begin
	       dvo <= 1;
	       row_addr <= 0;
	       col_addr <= 0;
	       
	    end else if (dtypei == `DTYPE_FRAME_START) begin
	       row_addr <= 0;
	       dvo <= 1;
	       
	    end else if (dtypei == `DTYPE_ROW_START) begin
	       col_addr <= 0;
	       dvo <= valid_row; // only start this row if it valid

	    end else if (dtypei == `DTYPE_ROW_END) begin
	       if (!(&row_addr)) begin // don't let row count overflow. Only nee
		  row_addr <= row_addr + 1; 
	       end
	       dvo <= valid_row; // only end this row if it valid

	    end else if(|(dtypei & `DTYPE_PIXEL_MASK)) begin
	       dvo <= valid_row && valid_col;
	       
	       col_addr <= col_addr + 1;
	       
	       for(row=0; row<KERNEL_SIZE; row=row+1) begin
		  for(col=0; col<KERNEL_SIZE-1; col=col+1) begin
		     datao[row][col] <= datao[row][col+1];
		  end
	       end

	       datao[KERNEL_SIZE-1][KERNEL_SIZE-1] <= datai[PIXEL_WIDTH-1:0];
	       for(row=0; row<KERNEL_SIZE-1; row=row+1) begin
		  datao[row][KERNEL_SIZE-1] <= rowbufo[row];
	       end

	    end else begin
	       dvo <= 1;
	    end
	 end else begin
	    dvo <= 0;
	 end

	 if (dvi) begin
	    if (dtypei == `DTYPE_HEADER) begin
	       header_addr <= header_addr + 1;
	    end else if (dtypei == `DTYPE_HEADER_START) begin
	       header_addr <= 0;
	    end
	 end

	 // adjust the image header to mark the smaller image
	 if(enable && dvi && 
	    ((header_addr == `Image_num_cols) || 
	     (header_addr == `Image_num_rows))) begin
	    /* verilator lint_off WIDTH */
	    meta_datao <= meta_datai - BORDER_SIZE;
	    /* verilator lint_on WIDTH */
	 end else begin
	    meta_datao <= meta_datai;
	 end
      end
   end
endmodule
