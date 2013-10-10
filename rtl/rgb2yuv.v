`include "terminals_defs.v"
`include "dtypes.v"

module rgb2yuv
  #(parameter DATA_WIDTH=8)
  (
   input clk,
   input resetb,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [3*DATA_WIDTH-1:0] datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [3*DATA_WIDTH-1:0] datao
   );

   reg [1:0] 	state;
   parameter STATE_IDLE=0, STATE_FRAME_DATA=1, STATE_HEADER_DATA=2;
   reg [5:0] 	header_addr;

   wire [DATA_WIDTH-1:0] r = datai[1*DATA_WIDTH-1:0*DATA_WIDTH];
   wire [DATA_WIDTH-1:0] g = datai[2*DATA_WIDTH-1:1*DATA_WIDTH];
   wire [DATA_WIDTH-1:0] b = datai[3*DATA_WIDTH-1:2*DATA_WIDTH];

   wire [DATA_WIDTH-1:0] y = dot_product( 66, 129,  25,   0);
   wire [DATA_WIDTH-1:0] u = dot_product(-38, -74, 112, 128);
   wire [DATA_WIDTH-1:0] v = dot_product(112, -94, -18, 128);
   
   
   function [DATA_WIDTH-1:0] dot_product;
      input signed [8:0] c0;
      input signed [8:0] c1;
      input signed [8:0] c2;
      input [DATA_WIDTH-1:0] offset;

      reg signed [DATA_WIDTH+8:0]  a0;
      reg signed [DATA_WIDTH+8:0]  a1;
      reg signed [DATA_WIDTH+8:0]  a2;
      reg signed [DATA_WIDTH+10:0] x1;
      reg signed [DATA_WIDTH+10:0] x2;
      reg signed [DATA_WIDTH+2:0]  x3;
      begin
	 a0 = r * c0;
	 a1 = g * c1;
	 a2 = b * c2;
	 /* verilator lint_off WIDTH */
	 x1 = a0 + a1 + a2 + 128; // add and round knowing divide by 256 is next
	 /* verilator lint_on WIDTH */
	 x2 = x1 >> 8;
	 x3 = x2[DATA_WIDTH+2:0] + {3'b0, offset};
	 
	 dot_product[DATA_WIDTH-1:0] = (x3 < 0) ? { DATA_WIDTH { 1'b0 }} :
				       (|x3[DATA_WIDTH+1:DATA_WIDTH]) ? { DATA_WIDTH { 1'b1 }} :
				       x3[DATA_WIDTH-1:0];
      end
   endfunction
   

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 state    <= STATE_IDLE;
	 header_addr <= 0;
	 
      end else begin
	 if(dvi && dtypei == `DTYPE_FRAME_START) begin
	    state <= STATE_FRAME_DATA;
	 end else if(dvi && dtypei == `DTYPE_HEADER_START) begin
	    state <= STATE_HEADER_DATA;
	 end else if(dvi && (dtypei == `DTYPE_FRAME_END || dtypei == `DTYPE_HEADER_END)) begin
	    state <= STATE_IDLE;
	 end
	 
	 dtypeo <= dtypei;
	 dvo    <= dvi;
	 if(state == STATE_FRAME_DATA) begin
	    if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
               datao[1*DATA_WIDTH-1 : 0*DATA_WIDTH] <= y;
               datao[2*DATA_WIDTH-1 : 1*DATA_WIDTH] <= u;
               datao[3*DATA_WIDTH-1 : 2*DATA_WIDTH] <= v;
	    end else begin
	       datao <= datai;
	    end
	    header_addr <= 0;

	 end else if(state == STATE_HEADER_DATA) begin
	    if(dvi && dtypei == `DTYPE_HEADER) begin
	      header_addr <= header_addr + 1;
	    end

	    if(header_addr == `Image_image_type) begin
	       datao[15:0] <= (datai[15:0] & 16'hFFC0) | 16'h0020;
	       datao[3*DATA_WIDTH-1:16] <= 0;
	    end else begin
	       datao <= datai;
	    end

	 end else begin
	    header_addr <= 0;
	    datao       <= datai;
	 end
      end
   end
endmodule
