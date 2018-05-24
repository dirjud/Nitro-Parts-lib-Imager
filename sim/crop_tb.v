`include "dtypes.v"

module crop_tb
  #(PIXEL_WIDTH=10, DIM_WIDTH=12)
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
    input [PIXEL_WIDTH-1:0]   r,
    input [PIXEL_WIDTH-1:0]   g,
    input [PIXEL_WIDTH-1:0]   b,
    input [15:0] 	      meta_datai,

    output 		      dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [PIXEL_WIDTH-1:0]  ro,
    output [PIXEL_WIDTH-1:0]  go,
    output [PIXEL_WIDTH-1:0]  bo,
    output [15:0] 	      meta_datao
   );
   
`include "CropTestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_CropTest) begin
	 di_reg_datao = CropTestTerminal_reg_datao;
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
   
   crop #(.PIXEL_WIDTH(3*PIXEL_WIDTH),
	  .DIM_WIDTH(DIM_WIDTH)
	  )
   crop
     (.clk(img_clk),
      .resetb(resetb),
      .enable(enable),
      .num_output_rows(num_output_rows),
      .num_output_cols(num_output_cols),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai({r, g, b}),
      .meta_datai(meta_datai),

      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao({ro, go, bo}),
      .meta_datao(meta_datao)
      );
endmodule
