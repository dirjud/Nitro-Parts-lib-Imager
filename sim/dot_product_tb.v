`include "dtypes.v"

module dot_product_tb
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

   parameter DATA_WIDTH=10;
   parameter COEFF_WIDTH = 8;
   parameter COEFF_FRAC_WIDTH = 5;
   wire [DATA_WIDTH-1:0] datao_ss, datao_us, datao_su, datao_uu;
   
`include "DotProductTestTerminalInstance.v"
   always @(*) begin
      if(di_term_addr == `TERM_DotProductTest) begin
	 di_reg_datao = DotProductTestTerminal_reg_datao;
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
   

   dot_product 
     #(
       .COEFF_WIDTH(COEFF_WIDTH),
       .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
       .DATA_WIDTH(DATA_WIDTH),
       .LENGTH(3),
       .SIGNED_COEFF(1),
       .SIGNED_DATA(1)
    )
   dot_product_ss
     (.datai({d0,d1,d2}),
      .coeff({c0,c1,c2}),
      .datao(datao_ss)
      );

   dot_product 
     #(
       .COEFF_WIDTH(COEFF_WIDTH),
       .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
       .DATA_WIDTH(DATA_WIDTH),
       .LENGTH(3),
       .SIGNED_COEFF(1),
       .SIGNED_DATA(0)
    )
   dot_product_su
     (.datai({d0,d1,d2}),
      .coeff({c0,c1,c2}),
      .datao(datao_su)
      );

   dot_product 
     #(
       .COEFF_WIDTH(COEFF_WIDTH),
       .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
       .DATA_WIDTH(DATA_WIDTH),
       .LENGTH(3),
       .SIGNED_COEFF(0),
       .SIGNED_DATA(1)
    )
   dot_product_us
     (.datai({d0,d1,d2}),
      .coeff({c0,c1,c2}),
      .datao(datao_us)
      );

   dot_product 
     #(
       .COEFF_WIDTH(COEFF_WIDTH),
       .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
       .DATA_WIDTH(DATA_WIDTH),
       .LENGTH(3),
       .SIGNED_COEFF(0),
       .SIGNED_DATA(0)
    )
   dot_product_uu
     (.datai({d0,d1,d2}),
      .coeff({c0,c1,c2}),
      .datao(datao_uu)
      );
   
endmodule
