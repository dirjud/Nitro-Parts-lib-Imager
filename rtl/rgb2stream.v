`include "dtypes.v"

module rgb2stream
  #(parameter PIXEL_WIDTH=10,
    parameter RAW_PIXEL_SHIFT=0
    )
  (input clk,
   input 		     resetb,
   input [15:0]		     image_type,

   input 		     dvi,
   input [`DTYPE_WIDTH-1:0]  dtypei,
   input [15:0] 	     meta_datai,
   input [PIXEL_WIDTH-1:0]   r,
   input [PIXEL_WIDTH-1:0]   g,
   input [PIXEL_WIDTH-1:0]   b,

   output reg 		     dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [31:0] 	     datao

   );

   parameter OBUF_WIDTH = 32 + 3*PIXEL_WIDTH;
   
   reg [OBUF_WIDTH-1:0] obuf;
   reg [5:0] 		opos;
   /* verilator lint_off WIDTH */
   wire [PIXEL_WIDTH-1:0] raw_data = meta_datai >> RAW_PIXEL_SHIFT;
   /* verilator lint_on WIDTH */
   
   wire [OBUF_WIDTH-1:0] next_obuf = (image_type == 0) ? { raw_data, obuf[OBUF_WIDTH-1:PIXEL_WIDTH] } :
                                                         { b, g, r, obuf[OBUF_WIDTH-1:3*PIXEL_WIDTH] };
   wire [5:0] 		 next_opos  = (image_type == 0) ? opos + PIXEL_WIDTH : 
			              opos + 3*PIXEL_WIDTH;
   wire [5:0] 		 next_opos2 = next_opos - 32;
   /* verilator lint_off WIDTH */
   wire [5:0] 		 next_opos3 = OBUF_WIDTH - next_opos;
   /* verilator lint_on WIDTH */
   
   wire [15:0] meta_datao = (opos == `Image_image_type) ? image_type :
	       meta_datai;
   
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 dtypeo <= 0;
	 datao <= 0;
	 obuf <= 0;
	 opos <= 0;
	 
      end else begin
	 dtypeo <= dtypei;

	 if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
	    obuf <= next_obuf;
	    if(next_opos >= 32) begin
	       dvo <= 1;
	       /* verilator lint_off WIDTH */
	       datao <= next_obuf >> next_opos3;
	       /* verilator lint_on WIDTH */
	       opos <= next_opos2;
	    end else begin
	       opos <= next_opos;
	       dvo <= 0;
	    end
	    
	 end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
	    opos <= 0;
	    dvo <= 1;
	    
	 end else if(dvi && dtypei == `DTYPE_HEADER_START) begin
	    opos <= 0;
	    dvo <= 1;

	 end else if(dvi && dtypei == `DTYPE_HEADER) begin
	    opos <= opos + 1;
	    if(opos[0]) begin
	       datao[31:16] <= meta_datao;
	       dvo <= 1;
	    end else begin
	       datao[15: 0] <= meta_datao;
	       dvo <= 0;
	    end
	 end else begin
	    dvo <= dvi;
	    datao <= 0;
	 end
      end
   end
endmodule
