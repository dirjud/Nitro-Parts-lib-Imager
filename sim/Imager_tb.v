`timescale 1ps/1ps
`include "terminals_defs.v"
`include "dtypes.v"

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
   
   reg [3:0]   rst_cnt;
   wire        resetb = &rst_cnt;
   initial rst_cnt = 0;
   always @(negedge clk) begin
      if(!resetb) begin
	 rst_cnt <= rst_cnt + 1;
      end
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

   wire [31:0] 	di_reg_datao_ROTATE;
   wire 	di_read_rdy_ROTATE, di_write_rdy_ROTATE, di_ROTATE_en;
   wire [15:0] 	di_transfer_status_ROTATE;

   wire [31:0] 	di_reg_datao_STREAM2DI;
   wire 	di_read_rdy_STREAM2DI;
   wire 	di_write_rdy_STREAM2DI = 0;
   wire di_STREAM2DI_en;
   wire [15:0] 	di_transfer_status_STREAM2DI = 0;

   wire [15:0] 	di_reg_datao_IMAGER_RX;
   wire 	di_read_rdy_IMAGER_RX, di_write_rdy_IMAGER_RX, di_IMAGER_RX_en;
   wire [15:0] 	di_transfer_status_IMAGER_RX;
   
   always @(*) begin
      if(di_term_addr == `TERM_Imager) begin
	 di_reg_datao = ImagerTerminal_reg_datao;
 	 di_read_rdy  = 1;
	 di_write_rdy = 1;
	 di_transfer_status = 0;
      end else if(di_IMAGER_RX_en) begin
	 di_reg_datao = {16'b0, di_reg_datao_IMAGER_RX};
	 di_read_rdy  = di_read_rdy_IMAGER_RX;
	 di_write_rdy = di_write_rdy_IMAGER_RX;
	 di_transfer_status = di_transfer_status_IMAGER_RX;
      end else if(di_ROTATE_en) begin
	 di_reg_datao = di_reg_datao_ROTATE;
	 di_read_rdy  = di_read_rdy_ROTATE;
	 di_write_rdy = di_write_rdy_ROTATE;
	 di_transfer_status = di_transfer_status_ROTATE;
      end else if(di_STREAM2DI_en) begin
	 di_reg_datao = di_reg_datao_STREAM2DI;
	 di_read_rdy  = di_read_rdy_STREAM2DI;
	 di_write_rdy = di_write_rdy_STREAM2DI;
	 di_transfer_status = di_transfer_status_STREAM2DI;
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

   /**************** Imager ********************/
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

   /**************** Imager RX ********************/
   wire [`DTYPE_WIDTH-1:0] dtypeo_rx;
   wire [15:0] 		   datao_rx;
   wire 		   dvo_rx;
   imager_rx
     #(.PIXEL_WIDTH(DATA_WIDTH),
       .DATA_WIDTH(16),
       .DIM_WIDTH(16)
       )
   imager_rx
     (.di_clk(clk),
      .resetb_di_clk(resetb),
      .di_term_addr(di_term_addr),
      .di_reg_addr(di_reg_addr),
      .di_read_mode(di_read_mode),
      .di_read_req(di_read_req),
      .di_read(di_read),
      .di_write_mode(di_write_mode),
      .di_write(di_write),
      .di_reg_datai(di_reg_datai[15:0]),
      .di_read_rdy(di_read_rdy_IMAGER_RX),
      .di_reg_datao(di_reg_datao_IMAGER_RX),
      .di_write_rdy(di_write_rdy_IMAGER_RX),
      .di_transfer_status(di_transfer_status_IMAGER_RX),
      .di_IMAGER_RX_en(di_IMAGER_RX_en),

      .enable(enable),
      .clki(clk),
      .resetb_clki(resetb),
      .fv(fv),
      .lv(lv),
      .dvi(1'b1),
      .datai(dat),

      .header_stall(0),
      .flags(0),
      .num_rows(),
      .num_cols(),
      .dvo(dvo_rx),
      .datao(datao_rx),
      .dtypeo(dtypeo_rx)
      );


   /**************** CCM Test Bench ********************/
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


   /**************** Rotate Test Bench ********************/
   wire 		   dvo_rotate;
   wire [15:0] 		   datao_rotate;
   wire [`DTYPE_WIDTH-1:0] dtypeo_rotate;
   rotate_tb #(.DATA_WIDTH(DATA_WIDTH))
	       rotate_tb
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
      .di_read_rdy(di_read_rdy_ROTATE),
      .di_reg_datao(di_reg_datao_ROTATE),
      .di_write_rdy(di_write_rdy_ROTATE),
      .di_transfer_status(di_transfer_status_ROTATE),
      .di_en(di_ROTATE_en),

      .img_clk(clk),
      .dvi(dvo_rx),
      .dtypei(dtypeo_rx),
      .datai(datao_rx),

      .dvo(dvo_rotate),
      .dtypeo(dtypeo_rotate),
      .datao(datao_rotate)
      );



   /**************** MUX to SELECT Reading Port ********************/
   reg [15:0] 		   datao_sel;
   reg 			   dvo_sel;
   reg [`DTYPE_WIDTH-1:0]  dtypeo_sel;
   always @(posedge clk) begin
      if(stream_sel == `Imager_stream_sel_RAW) begin
	 datao_sel  <=  datao_rx;
	 dtypeo_sel <= dtypeo_rx;
	 dvo_sel    <=    dvo_rx;
      end else if(stream_sel == `Imager_stream_sel_ROTATE) begin
	 datao_sel  <=  datao_rotate;
	 dtypeo_sel <= dtypeo_rotate;
	 dvo_sel    <=    dvo_rotate;
      end
   end

   /**************  STREAM 2 DI ***********************************/
   assign di_STREAM2DI_en = di_term_addr == `TERM_STREAM;
   stream2di stream2di
     (
      .enable(enable),
      .resetb(resetb),
      .clki(clk),
      .dvi(dvo_sel),
      .dtypei(dtypeo_sel),
      .datai(datao_sel),
      .rclk(clk),
      .di_read_mode(di_read_mode && di_STREAM2DI_en),
      .di_read(di_read && di_STREAM2DI_en),
      .di_read_rdy(di_read_rdy_STREAM2DI),
      .di_reg_datao(di_reg_datao_STREAM2DI)
      );

   
   
endmodule
