`include "terminals_defs.v"
`include "dtypes.v"
`include "array.v"

/*
 Author: Lane Brooks
 Date: 3/4/2017
 Description:
 
  2D filter. Supply 1D filter coeffs. These are applied twice. First
  in the horizontal (column) direction, and then in the vertical (row)
  direction. A border of (KERNEL_SIZE-1)/2 pixels is dropped from the
  image. Two clocks cycles of latency are incurred.
 
 The pipeline data is used to pass additional channels, such as the UV
 data and keep it pipeline aligned appropriately with the filtered
 channel.
 
 'orig_data' is the original output unaltered but pipeline
 aligned. This is useful if you need to perform additional operations
 with the original sample.
 */

module filter2d
  #(parameter PIXEL_WIDTH=8,
    parameter KERNEL_SIZE=3,
    parameter COEFF_WIDTH=8,
    parameter COEFF_FRAC_WIDTH=8,
    parameter COEFF_SIGNED=0,  // are the coeffecients signed=1, or unsigned=0
    parameter MAX_COLS=1288,
    parameter PIPELINE_DATA_WIDTH=0,
    parameter BLOCK_RAM=1
    )
  (
   input 				clk,
   input 				resetb,
   input 				enable,

   input [KERNEL_SIZE*COEFF_WIDTH-1:0] 	coeffs,
   
   input 				dvi,
   input [`DTYPE_WIDTH-1:0] 		dtypei,
   input [PIXEL_WIDTH-1:0] 		datai,
   input [PIPELINE_DATA_WIDTH-1:0] 	pipeline_datai,
   input [15:0] 			meta_datai,

   output reg 				dvo,
   output reg [`DTYPE_WIDTH-1:0] 	dtypeo,
   output reg [PIXEL_WIDTH-1:0] 	datao,
   output [15:0] 			meta_datao,
   output reg [PIXEL_WIDTH-1:0] 	orig_datao,
   output reg [PIPELINE_DATA_WIDTH-1:0] pipeline_datao
   );

   parameter MAX_COLS_WIDTH=$clog2(MAX_COLS);

   wire dvo_kernel, valid_row, valid_col;
   wire [`DTYPE_WIDTH-1:0] dtypeo_kernel;
   wire [PIXEL_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] kernel_datao;
   wire [PIPELINE_DATA_WIDTH-1:0] pipeline_datai_s;
   reg [PIPELINE_DATA_WIDTH-1:0]  pipeline_datai_ss, pipeline_datai_sss;
  
   kernel_with_pipeline 
     #(.KERNEL_SIZE(KERNEL_SIZE),
       .PIXEL_WIDTH(PIXEL_WIDTH),
       .DATA_WIDTH(16),
       .MAX_COLS(MAX_COLS),
       .PIPELINE_DATA_WIDTH(PIPELINE_DATA_WIDTH),
       .BLOCK_RAM(BLOCK_RAM))
   kernel
     (
      .clk(clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .meta_datai(meta_datai),
      .datai(datai),
      .pipeline_datai(pipeline_datai),
      .dvo(dvo_kernel),
      .meta_datao(meta_datao),
      .dtypeo(dtypeo_kernel),
      .kernel_datao(kernel_datao),
      .pipeline_datao(pipeline_datai_s)
      );

   wire dvi_filt1 = dvo_kernel && |(dtypeo_kernel & `DTYPE_PIXEL_MASK);
   wire [KERNEL_SIZE*PIXEL_WIDTH-1:0] datao_filt1;
   genvar x;
   generate
      for(x=0; x<KERNEL_SIZE; x=x+1) begin
	 filter1d #(.PIXEL_WIDTH(PIXEL_WIDTH),
		    .KERNEL_SIZE(KERNEL_SIZE),
		    .COEFF_WIDTH(COEFF_WIDTH),
		    .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
		    .COEFF_SIGNED(COEFF_SIGNED))
	 filter1d1
	   (.clk(clk),
	    .resetb(resetb),
	    .enable(enable),
	    .coeffs(coeffs),
	    .datai(kernel_datao[((x+1)*KERNEL_SIZE*PIXEL_WIDTH)-1:x*KERNEL_SIZE*PIXEL_WIDTH]),
	    .datao(datao_filt1[(x+1)*PIXEL_WIDTH-1:x*PIXEL_WIDTH])
	    );
      end
   endgenerate
   wire [PIXEL_WIDTH-1:0] d1[0:KERNEL_SIZE-1];
   `UNPACK_1DARRAY(idx1, PIXEL_WIDTH, KERNEL_SIZE, d1, datao_filt1)

   reg dvi_filt2, dvi_filt3, dvo_kernel_s, dvo_kernel_ss;
   reg [`DTYPE_WIDTH-1:0] dtypeo_kernel_s, dtypeo_kernel_ss;
   wire [PIXEL_WIDTH-1:0] datao_filt2;
   filter1d #(.PIXEL_WIDTH(PIXEL_WIDTH),
	      .KERNEL_SIZE(KERNEL_SIZE),
	      .COEFF_WIDTH(COEFF_WIDTH),
	      .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
	      .COEFF_SIGNED(COEFF_SIGNED))
   filter1d2
	   (.clk(clk),
	    .resetb(resetb),
	    .enable(enable),
	    .coeffs(coeffs),
	    .datai(datao_filt1),
	    .datao(datao_filt2)
	    );

   reg state;
   parameter STATE_IMAGE=0, STATE_META=1;
   wire frame_start = dvi && (dtypei == `DTYPE_FRAME_START);
   wire frame_end   = dvi && (dtypei == `DTYPE_FRAME_END);
   reg [PIXEL_WIDTH-1:0] orig_datao_p, orig_datao_pp;
   

   wire [PIXEL_WIDTH-1:0]  k[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
   `UNPACK_2DARRAY(unpk_idx, PIXEL_WIDTH, KERNEL_SIZE, KERNEL_SIZE, k, kernel_datao)
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 state             <= 0;
	 dvo               <= 0;
	 dtypeo            <= 0;
	 dvi_filt2         <= 0;
	 datao             <= 0;
	 dtypeo_kernel_s   <= 0;
	 dtypeo_kernel_ss  <= 0;
	 dvo_kernel_s      <= 0;
	 dvo_kernel_ss     <= 0;
	 dvi_filt3         <= 0;
	 pipeline_datai_ss <= 0;
	 pipeline_datai_sss<= 0;
	 orig_datao_p      <= 0;
	 orig_datao_pp     <= 0;
	 orig_datao        <= 0;
	 pipeline_datao    <= 0;
      end else begin // if (!resetb)
	 orig_datao_p <= k[KERNEL_SIZE/2][KERNEL_SIZE/2];
	 orig_datao_pp <= orig_datao_p;
	 orig_datao <= orig_datao_pp;
	 
	 dvi_filt2 <= dvi_filt1;
	 dvi_filt3 <= dvi_filt2;

	 pipeline_datai_ss<= pipeline_datai_s;
	 pipeline_datai_sss<= pipeline_datai_ss;
	 dvo_kernel_s  <= dvo_kernel;
	 dvo_kernel_ss <= dvo_kernel_s;
	 dtypeo_kernel_s  <= dtypeo_kernel;
	 dtypeo_kernel_ss <= dtypeo_kernel_s;
	 if(!enable || (state == STATE_META && !frame_start) || frame_end) begin
	    dvo    <= dvi;
	    dtypeo <= dtypei;
	    datao  <= datai;
	    pipeline_datao <= pipeline_datai;
	 end else begin
	    dvo    <= dvo_kernel_ss;
	    dtypeo <= dtypeo_kernel_ss;
	    datao  <= datao_filt2;
	    pipeline_datao <= pipeline_datai_sss;
	 end
	 if(frame_start) begin
	    state <= STATE_IMAGE;
	 end else if(frame_end) begin
	    state <= STATE_META;
	 end	 
      end
   end
   

endmodule


module filter1d
  #(parameter PIXEL_WIDTH=8,
    parameter KERNEL_SIZE=3,
    parameter COEFF_WIDTH=8,
    parameter COEFF_FRAC_WIDTH=7,
    parameter COEFF_SIGNED=0  // are the coeffecients signed=1, or unsigned=0
    )
  (input clk,
   input 			       resetb,
   input 			       enable,
   input [KERNEL_SIZE*COEFF_WIDTH-1:0] coeffs,
   input [KERNEL_SIZE*PIXEL_WIDTH-1:0] datai,
   output reg [PIXEL_WIDTH-1:0]        datao
   );

   wire [PIXEL_WIDTH-1:0] 	       datao_p;
   dot_product
     #(.COEFF_WIDTH(COEFF_WIDTH),
       .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
       .DATA_WIDTH(PIXEL_WIDTH),
       .LENGTH(KERNEL_SIZE),
       .SIGNED_COEFF(COEFF_SIGNED),
       .SIGNED_DATA(0))
   dot_product
     (.coeff(coeffs),
      .datai(datai),
      .datao(datao_p)
      );
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 datao <= 0;
      end else begin
	 if(!enable) begin
	    datao <= 0;
	 end else begin
	    datao <= datao_p;
	 end
      end
   end
endmodule
