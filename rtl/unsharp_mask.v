`include "terminals_defs.v"
`include "dtypes.v"
`include "array.v"

/*
 Author: Lane Brooks
 Date: 3/4/2017
 Description:
 
 Uses filter2d to apply an unsharp mask. You specify the high pass filter
 coefficients and the threshold. The coefficients are signed and should
 sum to 0. If the output of the highpass filter is greater than the 
 threshold, it will be added to the original sample.
 
 The pipeline data is used to pass additional channels, such as the UV
 data and keep it pipeline aligned appropriately with the filtered
 channel.
  */

module unsharp_mask
  #(parameter PIXEL_WIDTH=8,
    parameter KERNEL_SIZE=3,
    parameter COEFF_WIDTH=8,
    parameter COEFF_FRAC_WIDTH=7,
    parameter MAX_COLS=1288,
    parameter PIPELINE_DATA_WIDTH=0,
    parameter BLOCK_RAM=1
    )
  (
   input 				clk,
   input 				resetb,
   input 				enable,

   input [KERNEL_SIZE*COEFF_WIDTH-1:0] 	coeffs,
   input [PIXEL_WIDTH-1:0] 		threshold,
   
   input 				dvi,
   input [`DTYPE_WIDTH-1:0] 		dtypei,
   input [PIXEL_WIDTH-1:0] 		datai,
   input [PIPELINE_DATA_WIDTH-1:0] 	pipeline_datai,
   input [15:0] 			meta_datai,

   output reg 				dvo,
   output reg [`DTYPE_WIDTH-1:0] 	dtypeo,
   output reg [PIXEL_WIDTH-1:0] 	datao,
   output [15:0] 			meta_datao,
   output reg [PIPELINE_DATA_WIDTH-1:0] pipeline_datao
   );

   wire 				dvo0;
   wire [`DTYPE_WIDTH-1:0] 		dtypeo0;
   wire [PIXEL_WIDTH-1:0] 		datao0, orig_datao;
   wire [15:0] 				meta_datao0;
   wire [PIPELINE_DATA_WIDTH-1:0] 	pipeline_datao0;

   filter2d
     #(.PIXEL_WIDTH       (PIXEL_WIDTH),
       .KERNEL_SIZE       (KERNEL_SIZE),   
       .COEFF_WIDTH       (COEFF_WIDTH),
       .COEFF_FRAC_WIDTH  (COEFF_FRAC_WIDTH),
       .COEFF_SIGNED(1),
       .MAX_COLS(MAX_COLS),
       .PIPELINE_DATA_WIDTH(PIPELINE_DATA_WIDTH),
       .BLOCK_RAM(BLOCK_RAM))
   filter2d
   (.clk(clk),
    .resetb(resetb),
    .enable(enable),
    .coeffs(coeffs),
    .dvi(dvi),
    .dtypei(dtypei),
    .datai(datai),
    .pipeline_datai(pipeline_datai),
    .meta_datai(meta_datai),
    .dvo(dvo0),
    .dtypeo(dtypeo0),
    .datao(datao0),
    .orig_datao(orig_datao),
    .meta_datao(meta_datao0),
    .pipeline_datao(pipeline_datao0)
   );

   function [PIXEL_WIDTH-1:0] abs1;
      input [PIXEL_WIDTH-1:0] x;
      begin
	 if(x[PIXEL_WIDTH-1]) begin
	    abs1 = ~x + 1;
	 end else begin
	    abs1 = x;
	 end
      end
   endfunction // abs1

   wire signed [PIXEL_WIDTH+1:0] datao1 = {1'b0, orig_datao} + {datao0[PIXEL_WIDTH-1], datao0 };
   // clamp
   wire [PIXEL_WIDTH-1:0]      datao_sharpened = (datao1 < 0) ? 0 : 
			       (datao1[PIXEL_WIDTH]) ? {PIXEL_WIDTH{1'b1}} :
			       datao1[PIXEL_WIDTH-1:0];
   
   always @(posedge clk) begin
      if(!enable) begin
	 dvo    <= dvi;
	 dtypeo <= dtypei;
	 datao  <= datai;
	 meta_datao <= meta_datai;
	 pipeline_datao <= pipeline_datai;
      end else begin
	 dvo    <= dvo0;
	 dtypeo <= dtypeo0;
	 meta_datao <= meta_datao0;
	 pipeline_datao <= pipeline_datao0;
	 if(abs1(datao0) >= threshold) begin
	    datao <= datao_sharpened;
	 end else begin
	    datao <= orig_datao;
	 end
      end
   end
   
endmodule
