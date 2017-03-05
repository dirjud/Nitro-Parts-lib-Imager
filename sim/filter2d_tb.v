`include "dtypes.v"

module filter2d_tb
  #(PIXEL_WIDTH=10,
    KERNEL_SIZE=5,
    COEFF_WIDTH=8,
    COEFF_FRAC_WIDTH=6,
    COEFF_SIGNED=1,
    MAX_COLS=1288,
    MAX_COLS_WIDTH=11)
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
    input [PIXEL_WIDTH-1:0]   datai,
    input [15:0] 	      meta_datai,

    output 		      dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [PIXEL_WIDTH-1:0]  datao,
    output [15:0] 	      meta_datao
   );


`include "Filter2dTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_Filter2dTest) begin
	 di_reg_datao = Filter2dTestTerminal_reg_datao;
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
   
   filter2d #(.PIXEL_WIDTH(PIXEL_WIDTH),
	      .KERNEL_SIZE(KERNEL_SIZE),
	      .COEFF_WIDTH(COEFF_WIDTH),
	      .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
	      .COEFF_SIGNED(COEFF_SIGNED),
	      .MAX_COLS(MAX_COLS),
	      .MAX_COLS_WIDTH(MAX_COLS_WIDTH)
	      )
     filter2d
     (.clk(di_clk),
      .resetb(resetb),
      .enable(enable),
      .coeffs({c0,c1,c2,c1,c0}),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai),
      .meta_datai(meta_datai),
      
      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao(datao),
      .meta_datao(meta_datao)
      );
endmodule
