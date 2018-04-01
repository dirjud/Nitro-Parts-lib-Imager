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

   wire [31:0] 	di_reg_datao_DOTPRODUCT;
   wire 	di_read_rdy_DOTPRODUCT, di_write_rdy_DOTPRODUCT, di_DOTPRODUCT_en;
   wire [15:0] 	di_transfer_status_DOTPRODUCT;

   wire [31:0] 	di_reg_datao_RAWTO32;
   wire 	di_read_rdy_RAWTO32, di_write_rdy_RAWTO32, di_RAWTO32_en;
   wire [15:0] 	di_transfer_status_RAWTO32;

   wire [31:0] 	di_reg_datao_FILTER2D;
   wire 	di_read_rdy_FILTER2D, di_write_rdy_FILTER2D, di_FILTER2D_en;
   wire [15:0] 	di_transfer_status_FILTER2D;

   wire [31:0] 	di_reg_datao_UNSHARPMASK;
   wire 	di_read_rdy_UNSHARPMASK, di_write_rdy_UNSHARPMASK, di_UNSHARPMASK_en;
   wire [15:0] 	di_transfer_status_UNSHARPMASK;

   wire [31:0] 	di_reg_datao_STREAM2DI_INPUT;
   wire 	di_read_rdy_STREAM2DI_INPUT;
   wire 	di_write_rdy_STREAM2DI_INPUT = 0;
   wire 	di_STREAM2DI_INPUT_en;
   wire [15:0] 	di_transfer_status_STREAM2DI_INPUT = 0;

   wire [31:0] 	di_reg_datao_STREAM2DI_OUTPUT;
   wire 	di_read_rdy_STREAM2DI_OUTPUT;
   wire 	di_write_rdy_STREAM2DI_OUTPUT = 0;
   wire 	di_STREAM2DI_OUTPUT_en;
   wire [15:0] 	di_transfer_status_STREAM2DI_OUTPUT = 0;

   wire [15:0] 	di_reg_datao_IMAGER_RX;
   wire 	di_read_rdy_IMAGER_RX, di_write_rdy_IMAGER_RX, di_IMAGER_RX_en;
   wire [15:0] 	di_transfer_status_IMAGER_RX;
   
   wire 	di_INTERP_en, di_read_rdy_INTERP, di_write_rdy_INTERP;
   wire [31:0] 	di_reg_datao_INTERP;
   wire [15:0] 	di_transfer_status_INTERP;

   wire 	di_RGB2YUV_en, di_read_rdy_RGB2YUV, di_write_rdy_RGB2YUV;
   wire [31:0] 	di_reg_datao_RGB2YUV;
   wire [15:0] 	di_transfer_status_RGB2YUV;

   wire 	di_LOOKUP_MAP_en, di_read_rdy_LOOKUP_MAP, di_write_rdy_LOOKUP_MAP;
   wire [31:0] 	di_reg_datao_LOOKUP_MAP;
   wire [15:0] 	di_transfer_status_LOOKUP_MAP;
   
   wire [31:0] 	di_reg_datao_CIRCLE_CROP;
   wire 	di_read_rdy_CIRCLE_CROP, di_write_rdy_CIRCLE_CROP, di_CIRCLE_CROP_en;
   wire [15:0] 	di_transfer_status_CIRCLE_CROP;

   wire [31:0] 	di_reg_datao_ROTATE_YUV;
   wire 	di_read_rdy_ROTATE_YUV, di_write_rdy_ROTATE_YUV, di_ROTATE_YUV_en;
   wire [15:0] 	di_transfer_status_ROTATE_YUV;

   wire [31:0] 	di_reg_datao_YUV420;
   wire 	di_read_rdy_YUV420, di_write_rdy_YUV420, di_YUV420_en;
   wire [15:0] 	di_transfer_status_YUV420;

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
      end else if(di_ROTATE_YUV_en) begin
	 di_reg_datao = di_reg_datao_ROTATE_YUV;
	 di_read_rdy  = di_read_rdy_ROTATE_YUV;
	 di_write_rdy = di_write_rdy_ROTATE_YUV;
	 di_transfer_status = di_transfer_status_ROTATE_YUV;
      end else if(di_YUV420_en) begin
	 di_reg_datao = di_reg_datao_YUV420;
	 di_read_rdy  = di_read_rdy_YUV420;
	 di_write_rdy = di_write_rdy_YUV420;
	 di_transfer_status = di_transfer_status_YUV420;
      end else if(di_STREAM2DI_INPUT_en) begin
	 di_reg_datao = di_reg_datao_STREAM2DI_INPUT;
	 di_read_rdy  = di_read_rdy_STREAM2DI_INPUT;
	 di_write_rdy = di_write_rdy_STREAM2DI_INPUT;
	 di_transfer_status = di_transfer_status_STREAM2DI_INPUT;
      end else if(di_STREAM2DI_OUTPUT_en) begin
	 di_reg_datao = di_reg_datao_STREAM2DI_OUTPUT;
	 di_read_rdy  = di_read_rdy_STREAM2DI_OUTPUT;
	 di_write_rdy = di_write_rdy_STREAM2DI_OUTPUT;
	 di_transfer_status = di_transfer_status_STREAM2DI_OUTPUT;
      end else if(di_CCM_en) begin
	 di_reg_datao = di_reg_datao_CCM;
	 di_read_rdy  =  di_read_rdy_CCM;
	 di_write_rdy = di_write_rdy_CCM;
	 di_transfer_status = di_transfer_status_CCM;
      end else if(di_DOTPRODUCT_en) begin
	 di_reg_datao = di_reg_datao_DOTPRODUCT;
	 di_read_rdy  =  di_read_rdy_DOTPRODUCT;
	 di_write_rdy = di_write_rdy_DOTPRODUCT;
	 di_transfer_status = di_transfer_status_DOTPRODUCT;
      end else if(di_RAWTO32_en) begin
	 di_reg_datao = di_reg_datao_RAWTO32;
	 di_read_rdy  =  di_read_rdy_RAWTO32;
	 di_write_rdy = di_write_rdy_RAWTO32;
	 di_transfer_status = di_transfer_status_RAWTO32;
      end else if(di_FILTER2D_en) begin
	 di_reg_datao = di_reg_datao_FILTER2D;
	 di_read_rdy  =  di_read_rdy_FILTER2D;
	 di_write_rdy = di_write_rdy_FILTER2D;
	 di_transfer_status = di_transfer_status_FILTER2D;
      end else if(di_UNSHARPMASK_en) begin
	 di_reg_datao = di_reg_datao_UNSHARPMASK;
	 di_read_rdy  =  di_read_rdy_UNSHARPMASK;
	 di_write_rdy = di_write_rdy_UNSHARPMASK;
	 di_transfer_status = di_transfer_status_UNSHARPMASK;
      end else if(di_CIRCLE_CROP_en) begin
	 di_reg_datao = di_reg_datao_CIRCLE_CROP;
	 di_read_rdy  = di_read_rdy_CIRCLE_CROP;
	 di_write_rdy = di_write_rdy_CIRCLE_CROP;
	 di_transfer_status = di_transfer_status_CIRCLE_CROP;
      end else if(di_INTERP_en) begin
	 di_reg_datao = di_reg_datao_INTERP;
	 di_read_rdy  =  di_read_rdy_INTERP;
	 di_write_rdy = di_write_rdy_INTERP;
	 di_transfer_status = di_transfer_status_INTERP;
      end else if(di_RGB2YUV_en) begin
	 di_reg_datao = di_reg_datao_RGB2YUV;
	 di_read_rdy  =  di_read_rdy_RGB2YUV;
	 di_write_rdy = di_write_rdy_RGB2YUV;
	 di_transfer_status = di_transfer_status_RGB2YUV;
      end else if(di_LOOKUP_MAP_en) begin
	 di_reg_datao = di_reg_datao_LOOKUP_MAP;
	 di_read_rdy  =  di_read_rdy_LOOKUP_MAP;
	 di_write_rdy = di_write_rdy_LOOKUP_MAP;
	 di_transfer_status = di_transfer_status_LOOKUP_MAP;
      end else begin
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 1;
      end
   end

   /**************** Imager ********************/
   parameter PIXEL_WIDTH=10;
   wire [PIXEL_WIDTH-1:0] dat;
   wire 		 fv, lv, sync;
   imager 
      #(.DATA_WIDTH(PIXEL_WIDTH),
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
     #(.PIXEL_WIDTH(PIXEL_WIDTH),
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
   rotate_tb #(.DATA_WIDTH(PIXEL_WIDTH))
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

   /**************** Dot Product Test Bench ********************/
   dot_product_tb dot_product_tb
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
      .di_read_rdy(  di_read_rdy_DOTPRODUCT),
      .di_reg_datao(di_reg_datao_DOTPRODUCT),
      .di_write_rdy(di_write_rdy_DOTPRODUCT),
      .di_transfer_status(di_transfer_status_DOTPRODUCT),
      .di_en(di_DOTPRODUCT_en)
      );

   /**************** Dot Product Test Bench ********************/
   rotate_matrix_tb rotate_matrix_tb
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
      .di_read_rdy(  di_read_rdy_DOTPRODUCT),
      .di_reg_datao(di_reg_datao_DOTPRODUCT),
      .di_write_rdy(di_write_rdy_DOTPRODUCT),
      .di_transfer_status(di_transfer_status_DOTPRODUCT),
      .di_en(di_DOTPRODUCT_en)
      );

   
   /**************** Raw to 32 Test ********************/

   wire dvo_rawto32;
   wire [31:0] datao_rawto32;
   wire [`DTYPE_WIDTH-1:0] dtypeo_rawto32;
   raw_to_32_tb raw_to_32_tb
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
      .di_read_rdy(  di_read_rdy_RAWTO32),
      .di_reg_datao(di_reg_datao_RAWTO32),
      .di_write_rdy(di_write_rdy_RAWTO32),
      .di_transfer_status(di_transfer_status_RAWTO32),
      .di_en(di_RAWTO32_en),

      .img_clk(clk),
      .dvi(dvo_rx),
      .dtypei(dtypeo_rx),
      .datai(datao_rx),

      .dvo(dvo_rawto32),
      .dtypeo(dtypeo_rawto32),
      .datao(datao_rawto32)
   );


   /**************** Interp Test Bench ********************/
   wire 		          dvo_interp;
   wire [PIXEL_WIDTH-1:0] 	    r_interp, g_interp, b_interp;
   wire [15:0] 		   meta_datao_interp;
   wire [`DTYPE_WIDTH-1:0]     dtypeo_interp;
   interp_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   interp_tb
     (
      .resetb(resetb),
      .di_clk          (di_clk),         
      .di_term_addr	 (di_term_addr),	 
      .di_reg_addr	 (di_reg_addr),	 
      .di_read_mode	 (di_read_mode),	 
      .di_read_req	 (di_read_req),	 
      .di_read	 (di_read),	 
      .di_write_mode	 (di_write_mode),	 
      .di_write	 (di_write),	 
      .di_reg_datai	 (di_reg_datai),	 
      .di_read_rdy       (di_read_rdy_INTERP),       
      .di_reg_datao	    (di_reg_datao_INTERP),	    
      .di_write_rdy	    (di_write_rdy_INTERP),	    
      .di_transfer_status(di_transfer_status_INTERP),
      .di_en	    (di_INTERP_en),		    
      .img_clk(clk),
      .dvi(dvo_rx),
      .dtypei(dtypeo_rx),
      .datai(datao_rx),
      .dvo(dvo_interp),
      .dtypeo(dtypeo_interp),
      .r(r_interp),
      .g(g_interp),
      .b(b_interp),
      .meta_datao(meta_datao_interp));
   

   /**************** RGB2YUV Test Bench ********************/
   wire 		          dvo_rgb2yuv;
   wire [PIXEL_WIDTH-1:0] 	    y_rgb2yuv, u_rgb2yuv, v_rgb2yuv;
   wire [15:0] 		   meta_datao_rgb2yuv;
   wire [`DTYPE_WIDTH-1:0]     dtypeo_rgb2yuv;
   rgb2yuv_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   rgb2yuv_tb
     (
      .resetb(resetb),
      .di_clk          (di_clk),         
      .di_term_addr	 (di_term_addr),	 
      .di_reg_addr	 (di_reg_addr),	 
      .di_read_mode	 (di_read_mode),	 
      .di_read_req	 (di_read_req),	 
      .di_read	 (di_read),	 
      .di_write_mode	 (di_write_mode),	 
      .di_write	 (di_write),	 
      .di_reg_datai	 (di_reg_datai),	 
      .di_read_rdy       (di_read_rdy_RGB2YUV),       
      .di_reg_datao	    (di_reg_datao_RGB2YUV),	    
      .di_write_rdy	    (di_write_rdy_RGB2YUV),	    
      .di_transfer_status(di_transfer_status_RGB2YUV),
      .di_en	    (di_RGB2YUV_en),		    
      .img_clk(clk),
      .dvi(dvo_interp),
      .dtypei(dtypeo_interp),
      .r(r_interp),
      .g(g_interp),
      .b(b_interp),
      .dvo(dvo_rgb2yuv),
      .dtypeo(dtypeo_rgb2yuv),
      .y(y_rgb2yuv),
      .u(u_rgb2yuv),
      .v(v_rgb2yuv),
      .meta_datao(meta_datao_rgb2yuv));

   /**************** Rotate YUV Test Bench ********************/
   wire 		   dvo_rotate_yuv, rotate_yuv_enable;
   wire [15:0] 		   meta_datao_rotate_yuv;
   wire [7:0] 		   y_rotate_yuv;
   wire [7:0] 		   u_rotate_yuv;
   wire [7:0] 		   v_rotate_yuv;
   wire [`DTYPE_WIDTH-1:0] dtypeo_rotate_yuv;
   rotate_yuv_tb #(.DATA_WIDTH(PIXEL_WIDTH))
	       rotate_yuv_tb
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
      .di_read_rdy(di_read_rdy_ROTATE_YUV),
      .di_reg_datao(di_reg_datao_ROTATE_YUV),
      .di_write_rdy(di_write_rdy_ROTATE_YUV),
      .di_transfer_status(di_transfer_status_ROTATE_YUV),
      .di_en(di_ROTATE_YUV_en),
      .enable(rotate_yuv_enable),
      
      .img_clk(clk),
      .dvi(               dvo_rgb2yuv),
      .dtypei(         dtypeo_rgb2yuv),
      .meta_datai( meta_datao_rgb2yuv),
      .yi(                  y_rgb2yuv),
      .ui(                  u_rgb2yuv),
      .vi(                  v_rgb2yuv),

      .dvo(              dvo_rotate_yuv),
      .dtypeo(        dtypeo_rotate_yuv),
      .yo(                 y_rotate_yuv),
      .uo(                 u_rotate_yuv),
      .vo(                 v_rotate_yuv),
      .meta_datao(meta_datao_rotate_yuv)
      );

   /**************** YUV420 Test Bench ********************/
   wire 		   dvo_yuv420;
   wire [31:0] 		   datao_yuv420;
   wire [`DTYPE_WIDTH-1:0] dtypeo_yuv420;
   yuv420_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
	       yuv420_tb
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
      .di_read_rdy(di_read_rdy_YUV420),
      .di_reg_datao(di_reg_datao_YUV420),
      .di_write_rdy(di_write_rdy_YUV420),
      .di_transfer_status(di_transfer_status_YUV420),
      .di_en(di_YUV420_en),

      .img_clk(clk),
      .dvi(        rotate_yuv_enable ?        dvo_rotate_yuv :        dvo_rgb2yuv),
      .dtypei(     rotate_yuv_enable ?     dtypeo_rotate_yuv :     dtypeo_rgb2yuv),
      .meta_datai( rotate_yuv_enable ? meta_datao_rotate_yuv : meta_datao_rgb2yuv),
      .yi(         rotate_yuv_enable ?  {y_rotate_yuv, 2'b0} :          y_rgb2yuv),
      .ui(         rotate_yuv_enable ?  {u_rotate_yuv, 2'b0} :          u_rgb2yuv),
      .vi(         rotate_yuv_enable ?  {v_rotate_yuv, 2'b0} :          v_rgb2yuv),

      .dvo(               dvo_yuv420),
      .dtypeo(         dtypeo_yuv420),
      .datao(           datao_yuv420)
      );

   
   /**************** Filter2d Test Bench ********************/
   wire 		   dvo_filter2d;
   wire [PIXEL_WIDTH-1:0]  y_filter2d, u_filter2d, v_filter2d;
   wire [15:0] 		   meta_datao_filter2d;
   wire [`DTYPE_WIDTH-1:0] dtypeo_filter2d;
   filter2d_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   filter2d_tb
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
      .di_read_rdy(di_read_rdy_FILTER2D),
      .di_reg_datao(di_reg_datao_FILTER2D),
      .di_write_rdy(di_write_rdy_FILTER2D),
      .di_transfer_status(di_transfer_status_FILTER2D),
      .di_en(di_FILTER2D_en),

      .img_clk(clk),
      .dvi(               dvo_rgb2yuv),
      .dtypei(         dtypeo_rgb2yuv),
      .meta_datai( meta_datao_rgb2yuv),
      .yi(                  y_rgb2yuv),
      .ui(                  u_rgb2yuv),
      .vi(                  v_rgb2yuv),

      .dvo(              dvo_filter2d),
      .dtypeo(        dtypeo_filter2d),
      .yo(                 y_filter2d),
      .uo(                 u_filter2d),
      .vo(                 v_filter2d),
      .meta_datao(meta_datao_filter2d)
      );

   /**************** Filter2d Test Bench ********************/
   wire 		   dvo_unsharp_mask;
   wire [PIXEL_WIDTH-1:0]  y_unsharp_mask, u_unsharp_mask, v_unsharp_mask;
   wire [15:0] 		   meta_datao_unsharp_mask;
   wire [`DTYPE_WIDTH-1:0] dtypeo_unsharp_mask;
   unsharp_mask_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   unsharp_tb
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
      .di_read_rdy(di_read_rdy_UNSHARPMASK),
      .di_reg_datao(di_reg_datao_UNSHARPMASK),
      .di_write_rdy(di_write_rdy_UNSHARPMASK),
      .di_transfer_status(di_transfer_status_UNSHARPMASK),
      .di_en(di_UNSHARPMASK_en),

      .img_clk(clk),
      .dvi(               dvo_rgb2yuv),
      .dtypei(         dtypeo_rgb2yuv),
      .meta_datai( meta_datao_rgb2yuv),
      .yi(                  y_rgb2yuv),
      .ui(                  u_rgb2yuv),
      .vi(                  v_rgb2yuv),

      .dvo(              dvo_unsharp_mask),
      .dtypeo(        dtypeo_unsharp_mask),
      .yo(                 y_unsharp_mask),
      .uo(                 u_unsharp_mask),
      .vo(                 v_unsharp_mask),
      .meta_datao(meta_datao_unsharp_mask)
      );

   
   /**************** Lookup Map Test Bench ********************/
   wire 		          dvo_lookup_map;
   wire [PIXEL_WIDTH-1:0] 	    y_lookup_map, u_lookup_map, v_lookup_map;
   wire [15:0] 		   meta_datao_lookup_map;
   wire [`DTYPE_WIDTH-1:0]     dtypeo_lookup_map;
   lookup_map_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   lookup_map_tb
     (
      .resetb(resetb),
      .di_clk          (di_clk),         
      .di_term_addr	 (di_term_addr),	 
      .di_reg_addr	 (di_reg_addr),	 
      .di_read_mode	 (di_read_mode),	 
      .di_read_req	 (di_read_req),	 
      .di_read	 (di_read),	 
      .di_write_mode	 (di_write_mode),	 
      .di_write	 (di_write),	 
      .di_reg_datai	 (di_reg_datai),	 
      .di_read_rdy              (di_read_rdy_LOOKUP_MAP),       
      .di_reg_datao	       (di_reg_datao_LOOKUP_MAP),	    
      .di_write_rdy	       (di_write_rdy_LOOKUP_MAP),	    
      .di_transfer_status(di_transfer_status_LOOKUP_MAP),
      .di_en	    (di_LOOKUP_MAP_en),		    
      .img_clk(clk),
      .dvi(      dvo_rgb2yuv),
      .dtypei(dtypeo_rgb2yuv),
      .yi(         y_rgb2yuv),
      .ui(         u_rgb2yuv),
      .vi(         v_rgb2yuv),
      .dvo(              dvo_lookup_map),
      .dtypeo(        dtypeo_lookup_map),
      .yo(                 y_lookup_map),
      .uo(                 u_lookup_map),
      .vo(                 v_lookup_map),
      .meta_datao(meta_datao_lookup_map));

   /**************** Circle Crop Test Bench ********************/
   wire 		   dvo_circle_crop;
   wire [PIXEL_WIDTH-1:0]  r_circle_crop, g_circle_crop, b_circle_crop;
   wire [15:0] 		   meta_datao_circle_crop;
   wire [`DTYPE_WIDTH-1:0] dtypeo_circle_crop;
   circle_crop_tb #(.PIXEL_WIDTH(PIXEL_WIDTH))
   circle_crop_tb
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
      .di_read_rdy(di_read_rdy_CIRCLE_CROP),
      .di_reg_datao(di_reg_datao_CIRCLE_CROP),
      .di_write_rdy(di_write_rdy_CIRCLE_CROP),
      .di_transfer_status(di_transfer_status_CIRCLE_CROP),
      .di_en(di_CIRCLE_CROP_en),

      .img_clk(clk),
      .dvi(dvo_interp),
      .dtypei(dtypeo_interp),
      .r(r_interp),
      .g(g_interp),
      .b(b_interp),
      .meta_datai(meta_datao_interp),

      .dvo(dvo_circle_crop),
      .dtypeo(dtypeo_circle_crop),
      .ro(r_circle_crop),
      .go(g_circle_crop),
      .bo(b_circle_crop),
      .meta_datao(meta_datao_circle_crop)
      );

   /**************** MUX to SELECT Reading Port ********************/
   reg [15:0] 		   datao0_sel, datao1_sel, datao2_sel;
   reg [15:0] 		   meta_datao_sel;
   reg 			   dvo_sel;
   reg [`DTYPE_WIDTH-1:0]  dtypeo_sel;
   reg [15:0] 		   datai0_sel, datai1_sel, datai2_sel;
   reg [15:0] 		   meta_datai_sel;
   reg 			   dvi_sel;
   reg [`DTYPE_WIDTH-1:0]  dtypei_sel;
   /* verilator lint_off WIDTH */
   always @(posedge clk) begin
      if(stream_sel == `Imager_stream_sel_RAW) begin
	 datai0_sel     <=  datao_rx;
	 datai1_sel     <=  0;
	 datai2_sel     <=  0;
	 meta_datai_sel <=  datao_rx;
	 dtypei_sel     <= dtypeo_rx;
	 dvi_sel        <=    dvo_rx;
	 
	 datao0_sel     <=  datao_rx;
	 datao1_sel     <=  0;
	 datao2_sel     <=  0;
	 meta_datao_sel <=  datao_rx;
	 dtypeo_sel     <= dtypeo_rx;
	 dvo_sel        <=    dvo_rx;
      end else if(stream_sel == `Imager_stream_sel_ROTATE) begin
	 datai0_sel     <=  datao_rx;
	 datai1_sel     <=  0;
	 datai2_sel     <=  0;
	 meta_datai_sel <=  datao_rx;
	 dtypei_sel     <= dtypeo_rx;
	 dvi_sel        <=    dvo_rx;
	 
	 datao0_sel     <=  datao_rotate;
	 datao1_sel     <=  0;
	 datao2_sel     <=  0;
	 meta_datao_sel <=  datao_rotate;
	 dtypeo_sel     <= dtypeo_rotate;
	 dvo_sel        <=    dvo_rotate;
      end else if(stream_sel == `Imager_stream_sel_RAWTO32) begin
	 datai0_sel     <=  datao_rx;
	 datai1_sel     <=  0;
	 datai2_sel     <=  0;
	 meta_datai_sel <=  datao_rx;
	 dtypei_sel     <= dtypeo_rx;
	 dvi_sel        <=    dvo_rx;
	 
	 datao0_sel     <=  datao_rawto32[15:0];
	 datao1_sel     <=  datao_rawto32[31:16];
	 datao2_sel     <=  0;
	 meta_datao_sel <=  0;
	 dtypeo_sel     <= dtypeo_rawto32;
	 dvo_sel        <=    dvo_rawto32;
      end else if(stream_sel == `Imager_stream_sel_YUV420) begin
	 datai0_sel     <=          y_rgb2yuv;
	 datai1_sel     <=          u_rgb2yuv;
	 datai2_sel     <=          v_rgb2yuv;
	 meta_datai_sel <= meta_datao_rgb2yuv;
	 dtypei_sel     <=     dtypeo_rgb2yuv;
	 dvi_sel        <=        dvo_rgb2yuv;
	 datao0_sel     <=  datao_yuv420[15:0];
	 datao1_sel     <=  datao_yuv420[31:16];
	 datao2_sel     <=  0;
	 meta_datao_sel <=  0;
	 dtypeo_sel     <= dtypeo_yuv420;
	 dvo_sel        <=    dvo_yuv420;
      end else if(stream_sel == `Imager_stream_sel_CIRCLE_CROP) begin
	 datai0_sel     <=          r_interp;
	 datai1_sel     <=          g_interp;
	 datai2_sel     <=          b_interp;
	 meta_datai_sel <= meta_datao_interp;
	 dtypei_sel     <=     dtypeo_interp;
	 dvi_sel        <=        dvo_interp;
	 
	 datao0_sel     <=          r_circle_crop;
	 datao1_sel     <=          g_circle_crop;
	 datao2_sel     <=          b_circle_crop;
	 meta_datao_sel <= meta_datao_circle_crop;
	 dtypeo_sel     <=     dtypeo_circle_crop;
	 dvo_sel        <=        dvo_circle_crop;
      end else if(stream_sel == `Imager_stream_sel_FILTER2D) begin
	 datai0_sel     <=          y_rgb2yuv;
	 datai1_sel     <=          u_rgb2yuv;
	 datai2_sel     <=          v_rgb2yuv;
	 meta_datai_sel <= meta_datao_rgb2yuv;
	 dtypei_sel     <=     dtypeo_rgb2yuv;
	 dvi_sel        <=        dvo_rgb2yuv;
	 
	 datao0_sel     <=  y_filter2d;
	 datao1_sel     <=  u_filter2d;
	 datao2_sel     <=  v_filter2d;
	 meta_datao_sel <=  meta_datao_filter2d;
	 dtypeo_sel     <= dtypeo_filter2d;
	 dvo_sel        <=    dvo_filter2d;

      end else if(stream_sel == `Imager_stream_sel_UNSHARP_MASK) begin
	 datai0_sel     <=          y_rgb2yuv;
	 datai1_sel     <=          u_rgb2yuv;
	 datai2_sel     <=          v_rgb2yuv;
	 meta_datai_sel <= meta_datao_rgb2yuv;
	 dtypei_sel     <=     dtypeo_rgb2yuv;
	 dvi_sel        <=        dvo_rgb2yuv;
	 
	 datao0_sel     <=  y_unsharp_mask;
	 datao1_sel     <=  u_unsharp_mask;
	 datao2_sel     <=  v_unsharp_mask;
	 meta_datao_sel <=  meta_datao_unsharp_mask;
	 dtypeo_sel     <= dtypeo_unsharp_mask;
	 dvo_sel        <=    dvo_unsharp_mask;

      end else if(stream_sel == `Imager_stream_sel_INTERP) begin
	 datai0_sel     <=  datao_rx;
	 datai1_sel     <=  0;
	 datai2_sel     <=  0;
	 meta_datai_sel <=  datao_rx;
	 dtypei_sel     <= dtypeo_rx;
	 dvi_sel        <=    dvo_rx;
	 
	 datao0_sel     <=           r_interp;
	 datao1_sel     <=           g_interp;
	 datao2_sel     <=           b_interp;
	 meta_datao_sel <=  meta_datao_interp;
	 dtypeo_sel     <=      dtypeo_interp;
	 dvo_sel        <=         dvo_interp;
      end else if(stream_sel == `Imager_stream_sel_RGB2YUV) begin
	 datai0_sel     <=          r_interp;
	 datai1_sel     <=          g_interp;
	 datai2_sel     <=          b_interp;
	 meta_datai_sel <= meta_datao_interp;
	 dtypei_sel     <=     dtypeo_interp;
	 dvi_sel        <=        dvo_interp;
	 
	 datao0_sel     <=          y_rgb2yuv;
	 datao1_sel     <=          u_rgb2yuv;
	 datao2_sel     <=          v_rgb2yuv;
	 meta_datao_sel <= meta_datao_rgb2yuv;
	 dtypeo_sel     <=     dtypeo_rgb2yuv;
	 dvo_sel        <=        dvo_rgb2yuv;
      end else if(stream_sel == `Imager_stream_sel_ROTATE_YUV) begin
	 datai0_sel     <=          y_rgb2yuv;
	 datai1_sel     <=          u_rgb2yuv;
	 datai2_sel     <=          v_rgb2yuv;
	 meta_datai_sel <= meta_datao_rgb2yuv;
	 dtypei_sel     <=     dtypeo_rgb2yuv;
	 dvi_sel        <=        dvo_rgb2yuv;
	 
	 datao0_sel     <=  datao_yuv420[15:0];
	 datao1_sel     <=  datao_yuv420[31:16];
	 datao2_sel     <=  0;
	 meta_datao_sel <=  0;
	 dtypeo_sel     <= dtypeo_yuv420;
	 dvo_sel        <=    dvo_yuv420;
      end else if(stream_sel == `Imager_stream_sel_LOOKUP_MAP) begin
	 datai0_sel     <=          y_rgb2yuv;
	 datai1_sel     <=          u_rgb2yuv;
	 datai2_sel     <=          v_rgb2yuv;
	 meta_datai_sel <= meta_datao_rgb2yuv;
	 dtypei_sel     <=     dtypeo_rgb2yuv;
	 dvi_sel        <=        dvo_rgb2yuv;
	 
	 datao0_sel     <=          y_lookup_map;
	 datao1_sel     <=          u_lookup_map;
	 datao2_sel     <=          v_lookup_map;
	 meta_datao_sel <= meta_datao_lookup_map;
	 dtypeo_sel     <=     dtypeo_lookup_map;
	 dvo_sel        <=        dvo_lookup_map;
      end
   end
   /* verilator lint_on WIDTH */
   
   /**************  STREAM 2 DI ***********************************/
   assign di_STREAM2DI_INPUT_en = di_term_addr == `TERM_STREAM_INPUT;
   stream2di stream2di_input
     (
      .enable(enable),
      .resetb(resetb),
      .mode(capture_modei),
      .clki(clk),
      .dvi(dvi_sel),
      .dtypei(dtypei_sel),
      .datai0(datai0_sel),
      .datai1(datai1_sel),
      .datai2(datai2_sel),
      .meta_datai(meta_datai_sel),
      .rclk(clk),
      .di_read_mode(di_read_mode && di_STREAM2DI_INPUT_en),
      .di_read(di_read && di_STREAM2DI_INPUT_en),
      .di_read_rdy(di_read_rdy_STREAM2DI_INPUT),
      .di_reg_datao(di_reg_datao_STREAM2DI_INPUT)
      );

   /**************  STREAM 2 DI ***********************************/
   assign di_STREAM2DI_OUTPUT_en = di_term_addr == `TERM_STREAM_OUTPUT;
   stream2di stream2di_output
     (
      .enable(enable),
      .resetb(resetb),
      .mode(capture_modeo),
      .clki(clk),
      .dvi(dvo_sel),
      .dtypei(dtypeo_sel),
      .datai0(datao0_sel),
      .datai1(datao1_sel),
      .datai2(datao2_sel),
      .meta_datai(meta_datao_sel),
      .rclk(clk),
      .di_read_mode(di_read_mode && di_STREAM2DI_OUTPUT_en),
      .di_read(di_read && di_STREAM2DI_OUTPUT_en),
      .di_read_rdy(di_read_rdy_STREAM2DI_OUTPUT),
      .di_reg_datao(di_reg_datao_STREAM2DI_OUTPUT)
      );

endmodule
