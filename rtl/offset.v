`include "dtypes.v"

/*
 subtract specified offset from all pixels
 */

module offset
  #(parameter PIXEL_WIDTH=8,
    parameter DI_DATA_WIDTH=16)
  (
   input 			  clk,
   input 			  resetb,
   input 			  enable,
   input [PIXEL_WIDTH-1:0] 	  pix_offset,
   
   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [15:0] 		  datai,

   output reg 			  dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [15:0] 		  datao
   
   );


   wire [PIXEL_WIDTH:0]   datao_sub   = datai[PIXEL_WIDTH-1:0] - pix_offset;
   wire [PIXEL_WIDTH-1:0] datao_clamp = datao_sub[PIXEL_WIDTH] ? 0 : datao_sub[PIXEL_WIDTH-1:0];
   wire [15:0] 		  datao1 = { {(16-PIXEL_WIDTH) {1'b0}}, datao_clamp };
   wire [15:0] 		  datao_final = (|(dtypei & `DTYPE_PIXEL_MASK)) ?  datao1 : datai;
   
  always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 datao      <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         datao      <= (enable) ? datao_final : datai;
      end
   end
endmodule
