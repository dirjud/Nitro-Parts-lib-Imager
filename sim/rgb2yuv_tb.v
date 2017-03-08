`include "dtypes.v"

module rgb2yuv_tb
  #(parameter PIXEL_WIDTH=10)
   (
    input 		      resetb,
    // di interface
    input 		      di_clk,
    input [15:0] 	      di_term_addr,
    input [31:0] 	      di_reg_addr,
    input 		      di_read_mode,
    input 		      di_read_req,
    input 		      di_read,
    input 		      di_write_mode,
    input 		      di_write,
    input [31:0] 	      di_reg_datai,

    output reg 		      di_read_rdy,
    output reg [31:0] 	      di_reg_datao,
    output reg 		      di_write_rdy,
    output reg [15:0] 	      di_transfer_status,
    output reg 		      di_en,

    input 		      img_clk,
    input 		      dvi,
    input [`DTYPE_WIDTH-1:0]  dtypei,
    input [15:0] 	      meta_datai,
    input [PIXEL_WIDTH-1:0]   r,
    input [PIXEL_WIDTH-1:0]   g,
    input [PIXEL_WIDTH-1:0]   b,

    output 		      dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [PIXEL_WIDTH-1:0]  y,
    output [PIXEL_WIDTH-1:0]  u,
    output [PIXEL_WIDTH-1:0]  v,
    output [15:0] 	      meta_datao
   );


`include "Rgb2YuvTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_Rgb2YuvTest) begin
	 di_reg_datao = Rgb2YuvTestTerminal_reg_datao;
 	 di_read_rdy  = 1;
	 di_write_rdy = 1;
	 di_transfer_status = 0;
	 di_en = 1;
      end else begin
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 1;
	 di_en = 0;
      end
   end

   rgb2yuv #(.PIXEL_WIDTH(PIXEL_WIDTH))
   rgb2yuv
     (.clk(img_clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .r(r),
      .g(g),
      .b(b),
      .meta_datai(meta_datai),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .y(y),
      .u(u),
      .v(v),
      .meta_datao(meta_datao)
      );
endmodule
