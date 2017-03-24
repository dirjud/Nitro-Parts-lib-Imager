`include "dtypes.v"

module unsharp_mask_tb
  #(PIXEL_WIDTH=10,
    KERNEL_SIZE=5,
    COEFF_WIDTH=8,
    COEFF_FRAC_WIDTH=5,
    MAX_COLS=1288
    )
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
    input [PIXEL_WIDTH-1:0]   yi,
    input [PIXEL_WIDTH-1:0]   ui,
    input [PIXEL_WIDTH-1:0]   vi,
    input [15:0] 	      meta_datai,

    output 		      dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [PIXEL_WIDTH-1:0]  yo,
    output [PIXEL_WIDTH-1:0]  uo,
    output [PIXEL_WIDTH-1:0]  vo,
    output [15:0] 	      meta_datao
   );
   
`include "UnsharpMaskTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_UnsharpMaskTest) begin
	 di_reg_datao = UnsharpMaskTestTerminal_reg_datao;
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
   
   unsharp_mask #(.PIXEL_WIDTH(PIXEL_WIDTH),
	      .KERNEL_SIZE(KERNEL_SIZE),
	      .COEFF_WIDTH(COEFF_WIDTH),
	      .COEFF_FRAC_WIDTH(COEFF_FRAC_WIDTH),
	      .MAX_COLS(MAX_COLS),
	      .PIPELINE_DATA_WIDTH(2*PIXEL_WIDTH),
	      .BLOCK_RAM(0)
	      )
     unsharp_mask
     (.clk(di_clk),
      .resetb(resetb),
      .enable(enable),
      .coeffs({c0,c1,c2,c1,c0}),
      .threshold(threshold),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(yi),
      .pipeline_datai({ui,vi}),
      .meta_datai(meta_datai),
      
      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao(yo),
      .pipeline_datao({uo,vo}),
      .meta_datao(meta_datao)
      );
endmodule
