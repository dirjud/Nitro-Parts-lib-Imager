`include "dtypes.v"

module rotate_tb
  #(DATA_WIDTH=10)
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
   input [15:0] 	     datai,

   output 		     dvo,
   output [`DTYPE_WIDTH-1:0] dtypeo,
   output [15:0] 	     datao
   );


`include "RotateTestTerminalInstance.v"
   always @(*) begin
      if(di_term_addr == `TERM_RotateTest) begin
	 di_reg_datao = RotateTestTerminal_reg_datao;
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
   parameter ADDR_WIDTH=19;
   wire [ADDR_WIDTH-1:0] addr;
   wire        ceb, oeb, web;
   wire [15:0] ram_databus;
   
   rotate #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ANGLE_WIDTH(10))
     rotate
     (.clk(di_clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai),

      .sin_theta(sin_theta),
      .cos_theta(cos_theta),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao(datao),

      .addr(addr),
      .ceb(ceb),
      .web(web),
      .oeb(oeb),
      .ram_databus(ram_databus)

      );

   sram #(.ADDR_WIDTH(ADDR_WIDTH),
	  .DATA_WIDTH(16))
   sram
     (.ceb(ceb),
      .oeb(oeb),
      .web(web),
      .addr(addr),
      .data(ram_databus)
      );
   
endmodule
