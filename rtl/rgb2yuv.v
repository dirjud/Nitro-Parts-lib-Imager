`include "dtypes.v"
// Author: Lane Brooks
// Date: October 30, 2013

// Desc: Converts RGB data to YUV data. Y is converted as an unsigned
// number that spans the full range of the PIXEL_WIDTH. In other
// words, the offset of 16 is not added to the Y channel. This is so
// that later processing steps do not have to remove it prior to
// operating.  Furthermore, it also leaves U and V as signed numbers,
// which means it does not add the typical offset of 128 to make it an
// unsigned number. This is to make it easier for later processing
// steps that would typically have to first subtract the offset to
// make it signed prior to operating. This means that a final step
// before handing this YUV data off to something expecting more
// standard YUV data is to add the offsets to Y, U, and V channels.
//
// In summary this implements a matrix multiply that leaves the Y
// channel as an unsigned number and the U and V channel as signed
// numbers. Use the uv_offset module as the last processing step
// to add the offset to the U and V channels to make them customary.

module rgb2yuv
  #(parameter PIXEL_WIDTH=8)
  (
   input clk,
   input resetb,
   input enable,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [PIXEL_WIDTH-1:0] r,
   input [PIXEL_WIDTH-1:0] g,
   input [PIXEL_WIDTH-1:0] b,
   input [15:0] meta_datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [PIXEL_WIDTH-1:0] y,
   output reg [PIXEL_WIDTH-1:0] u,
   output reg [PIXEL_WIDTH-1:0] v,
   output reg [15:0] meta_datao
   );


   wire [PIXEL_WIDTH+9:0] y0;
   dot_product3
     #(.A_DATA_WIDTH(8),
       .B_DATA_WIDTH(PIXEL_WIDTH),
       .SIGNED(0))
   Ydot_product
     (.a0(66),
      .a1(129),
      .a2(25),
      .b0(r),
      .b1(g),
      .b2(b),
      .y(y0)
      );
   wire [PIXEL_WIDTH+9:0] y0a = y0 + 128; // round
   wire [PIXEL_WIDTH-1:0] y1;
   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+2),
   	   .DATAO_WIDTH(PIXEL_WIDTH),
   	   .SIGNED(0))
   Yclamp(.xi(y0a[PIXEL_WIDTH+9:8]), .xo(y1));
   
   wire [PIXEL_WIDTH+9:0] u0;
   wire [PIXEL_WIDTH-1:0] u1;
   dot_product3minus
     #(.A_DATA_WIDTH(8),
       .B_DATA_WIDTH(PIXEL_WIDTH),
       .SIGNED(0))
   Udot_product
     (.a0(112),
      .a1(38),
      .a2(74),
      .b0(b),
      .b1(r),
      .b2(g),
      .y(u0)
      );
   wire signed [PIXEL_WIDTH+9:0] u0a = u0 + 128; // round
   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+2),
   	   .DATAO_WIDTH(PIXEL_WIDTH),
   	   .SIGNED(1))
   Uclamp(.xi(u0a[PIXEL_WIDTH+9:8]), .xo(u1));

   wire [PIXEL_WIDTH+9:0] v0;
   wire [PIXEL_WIDTH-1:0] v1;
   dot_product3minus
     #(.A_DATA_WIDTH(8),
       .B_DATA_WIDTH(PIXEL_WIDTH),
       .SIGNED(0))
   Vdot_product
     (.a0(112),
      .a1(94),
      .a2(18),
      .b0(r),
      .b1(g),
      .b2(b),
      .y(v0)
      );
   wire signed [PIXEL_WIDTH+10:0] v0a = v0 + 128; // round
   clamp #(.DATAI_WIDTH(PIXEL_WIDTH+2),
   	   .DATAO_WIDTH(PIXEL_WIDTH),
   	   .SIGNED(0))
   Vclamp(.xi(v0a[PIXEL_WIDTH+9:8]), .xo(v1));
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 y          <= 0;
	 u          <= 0;
	 v          <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
         y          <= (enable) ? y1 : r;
         u          <= (enable) ? u1 : g;
         v          <= (enable) ? v1 : b;
	 meta_datao <= meta_datai;
      end
   end

endmodule


