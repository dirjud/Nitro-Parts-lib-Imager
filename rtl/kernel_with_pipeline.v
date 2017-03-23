`include "dtypes.v"
`include "array.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date: 3/23/2017

// Desc: Adds a pipeline delay block to the kernel.v module so that
// channels that do not need kernel'd can be kept in appropriate
// alignment. For example, if you have YUV data and only need a kernel
// on the Y data, send U and V into this module as the pipeline_datai
// and it will come out properly pipeline aligned with the kernel
// data.

module kernel_with_pipeline
  #(parameter KERNEL_SIZE = 3,
    parameter PIXEL_WIDTH = 10,
    parameter DATA_WIDTH  = 16,
    parameter MAX_COLS    = 1288,
    parameter PIPELINE_DATA_WIDTH=16,
    parameter BLOCK_RAM   = 1
    )
   (input                                            clk,
    input 					     resetb,
    input 					     dvi,
    input [`DTYPE_WIDTH-1:0] 			     dtypei,
    input [PIXEL_WIDTH-1:0] 			     datai,
    input [PIPELINE_DATA_WIDTH-1:0] 		     pipeline_datai,
    input [DATA_WIDTH-1:0] 			     meta_datai,
    input 					     enable,
    output 					     dvo,
    output [DATA_WIDTH-1:0] 			     meta_datao,
    output [`DTYPE_WIDTH-1:0] 			     dtypeo,
    output [KERNEL_SIZE*KERNEL_SIZE*PIXEL_WIDTH-1:0] kernel_datao,
    output [PIPELINE_DATA_WIDTH-1:0] 		     pipeline_datao
    );

   wire pd_we, pd_re0;
   reg 	pd_re, pd_re1;
   kernel #(.KERNEL_SIZE(KERNEL_SIZE),
	    .PIXEL_WIDTH(PIXEL_WIDTH),
	    .DATA_WIDTH(16),
	    .MAX_COLS(MAX_COLS),
	    .BLOCK_RAM(BLOCK_RAM))
   kernel
     (.clk(clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .meta_datai(meta_datai),
      .datai(datai),
      
      .dvo(dvo),
      .meta_datao(meta_datao),
      .dtypeo(dtypeo),
      .kernel_datao(kernel_datao)
      );

   row_delay_buffer 
     #(.DEPTH(2*MAX_COLS),
       .DATA_WIDTH(PIPELINE_DATA_WIDTH))
   row_delay_buffer
     (.clk(clk),
      .enable(enable && !(dvi && dtypei == `DTYPE_FRAME_START)),
      .we(pd_we),
      .datai(pipeline_datai),
      .re(pd_re),
      .datao(pipeline_datao)
      );

   reg 	valid_row;
   assign pd_we  = dvi && |(dtypei & `DTYPE_PIXEL_MASK);
   assign pd_re0 = dvi && |(dtypei & `DTYPE_PIXEL_MASK) && valid_row;

   parameter ROW_WIDTH = $clog2((KERNEL_SIZE+1)/2);
   reg [ROW_WIDTH-1:0] row_count;
   wire [ROW_WIDTH-1:0] next_row_count = row_count + 1;
   always @(posedge clk) begin
      pd_re1 <= pd_re0;
      pd_re  <= pd_re1;
      if(!enable || (dvi && dtypei == `DTYPE_FRAME_START)) begin
	 row_count <= 0;
	 valid_row <= 0;
      end else if(dvi && dtypei == `DTYPE_ROW_END) begin
	 /* verilator lint_off WIDTH */
	 if(next_row_count == KERNEL_SIZE/2) begin
	 /* verilator lint_on WIDTH */
	    valid_row <= 1;
	 end else begin
	    row_count <= row_count + 1;
	 end
      end
   end
   
endmodule


module row_delay_buffer
  #(parameter DEPTH=1288*2,
    parameter DATA_WIDTH=16)
  (input clk,
   input 		       enable,
   input 		       we,
   input [DATA_WIDTH-1:0]      datai,
   input 		       re,
   output reg [DATA_WIDTH-1:0] datao
   );

   parameter ADDR_WIDTH=$clog2(DEPTH);

   reg [ADDR_WIDTH-1:0]    waddr, raddr;
   reg [DATA_WIDTH-1:0]    buffer[0:DEPTH-1];
   wire [ADDR_WIDTH-1:0]   next_waddr = waddr + 1;
   wire [ADDR_WIDTH-1:0]   next_raddr = raddr + 1;
   always @(posedge clk) begin
      if(we) begin
	 buffer[waddr] <= datai;
      end
      datao <= buffer[raddr];
   end
   always @(posedge clk) begin
      if(!enable) begin
	 waddr <= 0;
	 raddr <= 0;
      end else begin
	 /* verilator lint_off WIDTH */
	 if(we) begin
	    waddr <= (next_waddr == DEPTH) ? 0 : next_waddr;
	 end
	 if(re) begin
	    raddr <= (next_raddr == DEPTH) ? 0 : next_raddr;
	 end
	 /* verilator lint_on WIDTH */
      end
   end
endmodule
