`include "dtypes.v"
// Date: 10/1/2013
// Description: Implements KERNEL_SIZE row buffers and outputs a KERNEL_SIZE x KERNEL_SIZE output

module ImageKernel
  #(parameter KERNEL_SIZE = 3,
    parameter DATA_WIDTH  = 8,
    parameter MAX_COLS    = 1280)
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
   reg [LOG2_MAX_COLS-1:0] wpos, rpos;
   
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 wpos <= 0;
	 rpos <= 0;
      end else begin

	 if (dvi) begin
	    if (dtypei == `DTYPE_FRAME_START) begin
	       
	    end else if (dtypei == `DTYPE_ROW_START) begin

	    end else begin

	    end
	 end
      end
   
endmodule
