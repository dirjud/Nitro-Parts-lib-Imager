`timescale 1ps/1ps
`include "terminals_defs.v"

module Imager_tb
  (
`ifdef verilator   
   input clk
`endif   
   );

`ifndef verilator
   reg   clk;
   initial clk=0;
   //always #10417 clk = !clk; // # 48MHz clock
   always #9921 clk = !clk; // 50.4Hmz clk
`endif

   wire  ifclk = clk;
   wire  di_clk = clk;

   wire [31:0] fx3_fd;
   wire [1:0]  fx3_fifo_addr;
   wire   fx3_dma_rdy_b;
   wire        fx3_ifclk, fx3_hics_b, fx3_sloe_b, fx3_slrd_b, fx3_slwr_b;
   wire        fx3_pktend_b, fx3_clkout, fx3_int_b;

   wire [31:0]  di_len, di_reg_addr, di_reg_datai, pt_di_reg_datao;
   wire [15:0]  di_term_addr, pt_di_transfer_status;
   reg [31:0] 	di_reg_datao;
   reg [15:0]	di_transfer_status;
   reg          di_read_rdy,  di_write_rdy;
   wire di_read, di_read_mode, pt_di_read_rdy, di_read_req;
   wire di_write, di_write_mode, pt_di_write_rdy;
   
   reg 	       resetb = 0;
   always @(negedge clk) begin
      resetb <= 1;
   end
   wire scl, sda;

   pullup(scl);
   pullup(sda);
   
   wire [31:0] 	fx3_fd_out, fx3_fd_in;
   wire 	fx3_fd_oe;
   assign fx3_fd    = (fx3_fd_oe) ? fx3_fd_out : 32'bZZZZ;
   assign fx3_fd_in = fx3_fd;

   fx3 fx3
     (
      .clk                                 (clk),
      .fx3_ifclk                           (fx3_ifclk),
      .fx3_hics_b                          (fx3_hics_b),
      .fx3_sloe_b                          (fx3_sloe_b),
      .fx3_slrd_b                          (fx3_slrd_b),
      .fx3_slwr_b                          (fx3_slwr_b),
      .fx3_pktend_b                        (fx3_pktend_b),
      .fx3_fifo_addr                       (fx3_fifo_addr),
      .fx3_fd                              (fx3_fd),
      .fx3_dma_rdy_b                       (fx3_dma_rdy_b),
      .SCL                                 (scl),
      .SDA                                 (sda)
      );

   Fx3HostInterface Fx3HostInterface
     (
      .ifclk(clk),
      .resetb(resetb),
      .di_term_addr (di_term_addr ),
      .di_reg_addr  (di_reg_addr  ),
      .di_len       (di_len       ),
      .di_read_mode (di_read_mode ),
      .di_read_req  (di_read_req  ),
      .di_read      (di_read      ),
      .di_read_rdy  (di_read_rdy  ),
      .di_reg_datao (di_reg_datao ),
      .di_write     (di_write     ),
      .di_write_rdy (di_write_rdy ),
      .di_write_mode(di_write_mode),
      .di_reg_datai (di_reg_datai ),
      .di_transfer_status(di_transfer_status),

      .fx3_hics_b(fx3_hics_b),
      .fx3_dma_rdy_b(fx3_dma_rdy_b),
      .fx3_sloe_b(fx3_sloe_b),
      .fx3_slrd_b(fx3_slrd_b),
      .fx3_slwr_b(fx3_slwr_b), 
      .fx3_pktend_b(fx3_pktend_b),
      .fx3_fifo_addr(fx3_fifo_addr),
      .fx3_fd_out(fx3_fd_out),
      .fx3_fd_in(fx3_fd_in),
      .fx3_fd_oe(fx3_fd_oe)
      );

`include "ImagerTerminalInstance.v"

   wire [31:0] 	di_reg_datao_CCM;
   wire 	di_read_rdy_CCM, di_write_rdy_CCM, di_CCM_en;
   wire [15:0] 	di_transfer_status_CCM;
   
   always @(*) begin
      if(di_term_addr == `TERM_Imager) begin
	 di_reg_datao = ImagerTerminal_reg_datao;
 	 di_read_rdy  = 1;
	 di_write_rdy = 1;
	 di_transfer_status = 0;
//      end else if(di_ROTATE_en) begin
//	 di_reg_datao = di_reg_datao_ROTATE;
//	 di_read_rdy  = di_read_rdy_ROTATE;
//	 di_write_rdy = di_write_rdy_ROTATE;
//	 di_transfer_status = di_transfer_status_ROTATE;
      end else if(di_CCM_en) begin
	 di_reg_datao = di_reg_datao_CCM;
	 di_read_rdy  =  di_read_rdy_CCM;
	 di_write_rdy = di_write_rdy_CCM;
	 di_transfer_status = di_transfer_status_CCM;
      end else begin
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 1;
      end
   end

   parameter DATA_WIDTH=10;
   wire [DATA_WIDTH-1:0] dat;
   wire 		 fv, lv, sync;
   imager 
      #(.DATA_WIDTH(DATA_WIDTH),
	.NUM_ROWS_WIDTH(12),
	.NUM_COLS_WIDTH(12))
   imager
     (
      .reset_n(resetb),
      .clk(clk),
      .enable(enable),
      .mode(mode),
      .bayer_red(bayer_red),
      .bayer_gr(bayer_gr),
      .bayer_blue(bayer_blue),
      .bayer_gb(bayer_gb),
      .num_active_rows(num_active_rows),
      .num_virtual_rows(num_virtual_rows),
      .num_active_cols(num_active_cols),
      .num_virtual_cols(num_virtual_cols),
      .sync_row_start(sync_row_start),
      .sync_rows(sync_rows),
      .noise_seed(noise_seed),
      .dat(dat),
      .fv(fv),
      .lv(lv),
      .sync(sync)
    );


   imager_rx
     #(
       .PIXEL_WIDTH(DATA_WIDTH),
       .DATA_WIDTH(16),
       .DIM_WIDTH(12)
       )
   imager_rx
     (
      .di_clk(clk),
      .resetb_di_clk(resetb),
      .di_term_addr(di_term_addr),
      .di_reg_addr(di_reg_addr),
      .di_read_mode(di_read_mode),
      .di_read_req(di_read_req),
      .di_read(di_read),
      .di_write_mode(di_write_mode),
      .di_write(di_write),
      .di_reg_datai(di_reg_datai),
      .di_read_rdy(di_read_rdy_IMAGER_RX),
      .di_reg_datao(di_reg_datao_IMAGER_RX),
      .di_write_rdy(di_write_rdy_IMAGER_RX),
      .di_transfer_status(di_transfer_status_IMAGER_RX),
      .di_IMAGER_RX_en(di_IMAGER_RX_en)

//    input 			  enable, // sync to di_clk
//    
//    input 			  clki,
//    input 			  resetb_clki,
//    input 			  fv,
//    input 			  lv,
//    input 			  dvi,
//    input [PIXEL_WIDTH-1:0] 	  datai,
//
//    input 			  header_stall,
//    input [15:0] 		  flags,
//    output reg [DIM_WIDTH-1:0] 	  num_rows,
//    output reg [DIM_WIDTH-1:0] 	  num_cols,
//    
//    output reg 			  dvo,
//    output reg [DATA_WIDTH-1:0]   datao,
//    output reg [`DTYPE_WIDTH-1:0] dtypeo
      );


   ccm_tb ccm_tb
     (
      .resetb(resetb),
      .di_clk(clk),
      .di_term_addr(di_term_addr),
      .di_reg_addr(di_reg_addr),
      .di_read_mode(di_read_mode),
      .di_read_req(di_read_req),
      .di_read(di_read),
      .di_write_mode(di_write_mode),
      .di_write(di_write),
      .di_reg_datai(di_reg_datai),
      .di_read_rdy(  di_read_rdy_CCM),
      .di_reg_datao(di_reg_datao_CCM),
      .di_write_rdy(di_write_rdy_CCM),
      .di_transfer_status(di_transfer_status_CCM),
      .di_en(di_CCM_en)
      );
   
//   rotate_tb rotate_tb
//     (
//      .resetb(resetb),
//      .di_clk(clk),
//      .di_term_addr(di_term_addr),
//      .di_reg_addr(di_reg_addr),
//      .di_read_mode(di_read_mode),
//      .di_read_req(di_read_req),
//      .di_read(di_read),
//      .di_write_mode(di_write_mode),
//      .di_write(di_write),
//      .di_reg_datai(di_reg_datai),
//      .di_read_rdy(di_read_rdy_ROTATE),
//      .di_reg_datao(di_reg_datao_ROTATE),
//      .di_write_rdy(di_write_rdy_ROTATE),
//      .di_transfer_status(di_transfer_status_ROTATE),
//      .di_en(di_ROTATE_en),
//
//      .img_clk(clk),
//      .dvi(dvi),
//      .dtypei(dtypei),
//      .datai(datai)
//      );

   
endmodule
