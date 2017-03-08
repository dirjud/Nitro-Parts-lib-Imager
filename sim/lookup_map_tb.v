`include "dtypes.v"

module lookup_map_tb
  #(PIXEL_WIDTH=10)
  (

   input 		     resetb,

   // di interface
   input 		     di_clk,
   input [15:0] 	     di_term_addr,
   input [31:0] 	     di_reg_addr,
   input 		     di_read_mode,
   input 		     di_read_req,
   input 		     di_read,
   input 		     di_write_mode,
   input 		     di_write,
   input [31:0] 	     di_reg_datai,

   output reg 		     di_read_rdy,
   output reg [31:0] 	     di_reg_datao,
   output reg 		     di_write_rdy,
   output reg [15:0] 	     di_transfer_status,
   output reg 		     di_en,

   input 		     img_clk,
   input 		     dvi,
   input [`DTYPE_WIDTH-1:0]  dtypei,
   input [15:0] 	     meta_datai,
   input [PIXEL_WIDTH-1:0]   yi,
   input [PIXEL_WIDTH-1:0]   ui,
   input [PIXEL_WIDTH-1:0]   vi,

   output 		     dvo,
   output [`DTYPE_WIDTH-1:0] dtypeo,
   output [15:0] 	     meta_datao,
   output [PIXEL_WIDTH-1:0]   yo,
   output [PIXEL_WIDTH-1:0]   uo,
   output [PIXEL_WIDTH-1:0]   vo
   );

`include "LookupMapTestTerminalInstance.v"
   wire di_read_rdy_LOOKUP_MAP, di_write_rdy_LOOKUP_MAP, di_LOOKUP_MAP_en;
   wire [15:0] di_reg_datao_LOOKUP_MAP;
   wire [15:0] di_transfer_status_LOOKUP_MAP;

   always @(*) begin
      if(di_term_addr == `TERM_LookupMapTest) begin
	 di_reg_datao = LookupMapTestTerminal_reg_datao;
 	 di_read_rdy  = 1;
	 di_write_rdy = 1;
	 di_transfer_status = 0;
	 di_en = 1;
      end else if(di_LOOKUP_MAP_en) begin
	 di_reg_datao = {16'b0, di_reg_datao_LOOKUP_MAP};
 	 di_read_rdy  = di_read_rdy_LOOKUP_MAP;
	 di_write_rdy = di_write_rdy_LOOKUP_MAP;
	 di_transfer_status = di_transfer_status_LOOKUP_MAP;
	 di_en = 1;
      end else begin
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 1;
	 di_en = 0;
      end
   end

   lookup_map #(.PIXEL_WIDTH(PIXEL_WIDTH))
   lookup_map
     (
      .pixclk(img_clk),
      .resetb(resetb),
      .enable(enable),
      .di_clk(di_clk),
      .di_term_addr  (di_term_addr),
      .di_reg_addr	(di_reg_addr), 
      .di_read_mode	(di_read_mode),
      .di_read_req	(di_read_req), 
      .di_read	(di_read),     
      .di_write_mode	(di_write_mode),
      .di_write	(di_write),    
      .di_reg_datai	(di_reg_datai[15:0]),
      .di_read_rdy       (di_read_rdy_LOOKUP_MAP),	     
      .di_reg_datao      (di_reg_datao_LOOKUP_MAP),	     
      .di_write_rdy	   (di_write_rdy_LOOKUP_MAP),	     
      .di_transfer_status(di_transfer_status_LOOKUP_MAP), 
      .di_en             (di_LOOKUP_MAP_en),
      
      .dvi(dvi),
      .dtypei(dtypei),
      .y(yi),
      .u(ui),
      .v(vi),
      .meta_datai(meta_datai),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .yo(yo),
      .uo(uo),
      .vo(vo),
      .meta_datao(meta_datao)
      );

endmodule
