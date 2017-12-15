`include "dtypes.v"

module interp_tb
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


`include "InterpTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_InterpTest) begin
	 di_reg_datao = InterpTestTerminal_reg_datao;
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

   wire 		         dvo_bilinear;
   wire [`DTYPE_WIDTH-1:0]    dtypeo_bilinear;
   wire [PIXEL_WIDTH-1:0]          r_bilinear;
   wire [PIXEL_WIDTH-1:0]          g_bilinear;
   wire [PIXEL_WIDTH-1:0]          b_bilinear;
   wire [15:0]            meta_datao_bilinear;

   wire 		         dvo_ed;
   wire [`DTYPE_WIDTH-1:0]    dtypeo_ed;
   wire [PIXEL_WIDTH-1:0]          r_ed;
   wire [PIXEL_WIDTH-1:0]          g_ed;
   wire [PIXEL_WIDTH-1:0]          b_ed;
   wire [15:0]            meta_datao_ed;
   
   interp_bilinear #(.PIXEL_WIDTH(PIXEL_WIDTH),
		     .MAX_COLS(MAX_COLS))
   interp_bilinear
     (.clk(img_clk),
      .resetb(resetb),
      .enable(enable_bilinear),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai),
      .phase(phase),
      .dvo(dvo_bilinear),
      .r(r_bilinear),
      .g(g_bilinear),
      .b(b_bilinear),
      .dtypeo(dtypeo_bilinear),
      .meta_datao(meta_datao_bilinear)
      );

   interp_ed #(.PIXEL_WIDTH(PIXEL_WIDTH),
		     .MAX_COLS(MAX_COLS))
   interp_ed
     (.clk(img_clk),
      .resetb(resetb),
      .enable(enable_ed),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai),
      .phase(phase),
      .dvo(dvo_ed),
      .r(r_ed),
      .g(g_ed),
      .b(b_ed),
      .dtypeo(dtypeo_ed),
      .meta_datao(meta_datao_ed)
      );

   assign        dvo = (enable_ed) ?        dvo_ed :        dvo_bilinear;
   assign     dtypeo = (enable_ed) ?     dtypeo_ed :     dtypeo_bilinear;
   assign          r = (enable_ed) ?          r_ed :          r_bilinear;
   assign          g = (enable_ed) ?          g_ed :          g_bilinear;
   assign          b = (enable_ed) ?          b_ed :          b_bilinear;
   assign meta_datao = (enable_ed) ? meta_datao_ed : meta_datao_bilinear;

endmodule
