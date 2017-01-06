`include "dtypes.v"

module ccm_tb
  (

   input 			  resetb,

   // di interface
   input 			  di_clk,
   input [15:0] 		  di_term_addr,
   input [31:0] 		  di_reg_addr,
   input 			  di_read_mode,
   input 			  di_read_req,
   input 			  di_read,
   input 			  di_write_mode,
   input 			  di_write,
   input [31:0] 	  di_reg_datai,

   output reg 			  di_read_rdy,
   output reg [31:0] di_reg_datao,
   output reg 			  di_write_rdy,
   output reg [15:0] 		  di_transfer_status,
   output reg 			  di_en
   );

   reg [9:0] 			  ro, bo, go;
   wire [9:0] 			  r0, g0, b0;
   wire 			  dvo;
   
`include "CcmTestTerminalInstance.v"
   always @(*) begin
      if(di_term_addr == `TERM_CcmTest) begin
	 di_reg_datao = CcmTestTerminal_reg_datao;
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
   

   ccm #(.PIXEL_WIDTH(10), .COEFF_WIDTH(8), .COEFF_FRAC_WIDTH(5)) ccm
     (.clk(di_clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei({`DTYPE_WIDTH{1'b0}}), // doesn't matter
      .ri(ri),
      .gi(gi),
      .bi(bi),
      .meta_datai(16'b0), // doesn't matter
      .RR(RR),
      .RG(RG),
      .RB(RB),
      .GR(GR),
      .GG(GG),
      .GB(GB),
      .BR(BR),
      .BG(BG),
      .BB(BB),
      .dvo(dvo),
      .dtypeo(),
      .ro(r0),
      .go(g0),
      .bo(b0),
      .meta_datao()
      );

   always @(posedge di_clk) begin
      if(dvo) begin
	 ro <= r0;
	 go <= g0;
	 bo <= b0;
      end
   end

endmodule
