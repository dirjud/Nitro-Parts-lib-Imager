`include "dtypes.v"

module interp_bilinear_tb
  #(parameter PIXEL_WIDTH=10,
    parameter MAX_COLS    = 1288)
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
    input [15:0] 	      datai,

    output 		      dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [PIXEL_WIDTH-1:0]  r,
    output [PIXEL_WIDTH-1:0]  g,
    output [PIXEL_WIDTH-1:0]  b,
    output [15:0] 	      meta_datao
   );


`include "InterpBilinearTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_InterpBilinearTest) begin
	 di_reg_datao = InterpBilinearTestTerminal_reg_datao;
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

   interp_bilinear #(.PIXEL_WIDTH(PIXEL_WIDTH),
		     .MAX_COLS(MAX_COLS))
   interp_bilinear
     (.clk(img_clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai),
      .phase(phase),
      .dvo(dvo),
      .r(r),
      .g(g),
      .b(b),
      .dtypeo(dtypeo),
      .meta_datao(meta_datao)
      );
endmodule
