// Author: Lane Brooks
// Desc:   Receives data from an image sensor and formats it for an
//         image processing pipeline.
//
//      dvo:    data valid out
//      dtypeo: data type out
//      datao:  data out
// 
//     We don't know yet what type of data this is, so we set it type
//     `DTYPE_PIXEL. Later streams can deal with assigning it the
//     correct color and whatnot. Later streams can deal with packing it, 
//     processing it, etc.
//
//    This puts the HEADER at the end of the image stream, when it is
//    enabled.
//
// Notes:
//  * If fv (frame valid) goes high at the same time as lv (line valid),
//    then a `DTYPE_FRAME_START will trump the `DTYPE_ROW_START and you
//    will not get a `DTYPE_ROW_START.
//
//  * If fv drops at the same time lv does, the `DTYPE_FRAME_END will
//    trump over the `DTYPE_ROW_END so you will not get a `DTYPE_ROW_END
//    in the image stream.
//

`include "dtypes.v"
`include "terminals_defs.v"

module imager_rx
   #(parameter PIXEL_WIDTH=12,
     parameter DATA_WIDTH=16,
     parameter DIM_WIDTH=16)
   (

    input 			  di_clk,
    input 			  resetb_di_clk,
    input [15:0] 		  di_term_addr,
    input [31:0] 		  di_reg_addr,
    input 			  di_read_mode,
    input 			  di_read_req,
    input 			  di_read,
    input 			  di_write_mode,
    input 			  di_write,
    input [15:0] 		  di_reg_datai,
    output reg 			  di_read_rdy,
    output reg [15:0] 		  di_reg_datao,
    output reg 			  di_write_rdy,
    output reg [15:0] 		  di_transfer_status,
    output reg 			  di_IMAGER_RX_en,

    input 			  enable, // sync to di_clk
    
    input 			  clki,
    input 			  resetb_clki,
    input 			  fv,
    input 			  lv,
    input             dvi,
    input [PIXEL_WIDTH-1:0] 	  datai,

    input 			  header_stall,
    input [15:0] 		  flags,
    
    output reg 			  dvo,
    output reg [DATA_WIDTH-1:0]   datao,
    output reg [`DTYPE_WIDTH-1:0] dtypeo
    );
   
   reg fv_s, fv_ss, fv_sss, lv_s, lv_ss, dv_s, dv_ss;
   reg [PIXEL_WIDTH-1:0] datai_s, datai_ss;

`ifndef IMAGERRX_NO_IOB
   // the reason to comment these out would be if your
   // fv, lv do not come directly from an off chip source
   // i.e, you're generating them or have some other 
   // process in between this module and the source.
   // that gets rid of some xilinx warnings about not being
   // able to route them in the most optimal way.
   // synthesis attribute IOB of fv_s  is "TRUE";
   // synthesis attribute IOB of lv_s  is "TRUE";
   // synthesis attribute IOB of datai is "TRUE";
`endif
   
   reg [DIM_WIDTH-1:0] row_count, col_count;
   reg [DIM_WIDTH-1:0] num_rows, num_cols;
   reg [31:0] frame_cycles_count, clks_per_frame;
   reg [15:0] checksum, frame_count, clks_per_row;

   wire [31:0] frame_start = 32'hFFFFFFFE;
   wire [29:0] frame_length = 0;
   wire [15:0] imageHeaderVersion = 2;
   wire [15:0] image_type = 0;
   wire [15:0] image_data = 0;

   wire resetb = resetb_di_clk;
`include "ImagerRxTerminalInstance.v"
   
   always @(*) begin
      if(di_term_addr == `TERM_ImagerRx) begin
         di_IMAGER_RX_en = 1;
         di_reg_datao = ImagerRxTerminal_reg_datao;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 0;
      end else begin
         di_IMAGER_RX_en = 0;
         di_reg_datao = 16'hAAAA;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 16'hFFFD; // undefined terminal, return error code
      end
   end

   wire       fv_rising         = ( fv_s && !fv_ss);
   wire       fv_falling        = (!fv_s &&  fv_ss);
   wire       lv_rising         = ( lv_s && !lv_ss);
   wire       lv_falling        = (!lv_s &&  lv_ss);

   reg 	      lv_falling_s, fv_falling_s;
   reg 	      enable_s, wait_for_fv_to_drop, header_stall_s;
   reg [15:0] clks_per_row_count;
   reg [15:0] flags_s, flags_ss;
   
   wire       dv = fv_ss && lv_ss && dv_ss;
   reg [1:0]  header_mode;
   reg [5:0]  header_addr;
   wire [15:0] header_data;
  ImageTerminal ImageTerminal(
     .clk(clki),
     .resetb(resetb_clki),
     .we(1'b0),
     .addr({10'b0, header_addr}),
     .datai(16'b0),
     .datao(header_data),

     .frame_start(frame_start),
     .frame_length(frame_length),
     .imageHeaderVersion(imageHeaderVersion),
     .num_rows(num_rows),
     .num_cols(num_cols),
     .frame_count(frame_count),
     .clks_per_frame(clks_per_frame),
     .clks_per_row(clks_per_row),
     .checksum(checksum),
     .image_type(image_type),
     .flags(flags_ss),
     .image_data(image_data)
     );

   /* verilator lint_off WIDTH */
   wire [PIXEL_WIDTH-1:0] test_pat = row_count + col_count; // + frame_count;
   /* verilator lint_on WIDTH */
   wire [PIXEL_WIDTH-1:0] datai_s_mux = (mode_test_pat) ? test_pat : datai_s;
   reg 			  left_justify_s;
   /* verilator lint_off LITENDIAN */
   wire [DATA_WIDTH-PIXEL_WIDTH-1:0] zero_padding = 0;
   /* verilator lint_on LITENDIAN */
   /* verilator lint_off WIDTH */
   wire [DATA_WIDTH-1:0] datai_formatted = (DATA_WIDTH == PIXEL_WIDTH) ? datai_ss :
			 left_justify_s ? { datai_ss, zero_padding } : { zero_padding, datai_ss };
   /* verilator lint_on WIDTH */

   reg 			 header_addr0_s;
   always @(posedge clki or negedge resetb_clki) begin
      if(!resetb_clki) begin
	 fv_s          <= 0;
	 lv_s          <= 0;
	 datai_s       <= 0;
	 fv_ss         <= 0;
	 lv_ss         <= 0;
     dv_s          <= 0;
     dv_ss         <= 0;
	 datai_ss      <= 0;
	 fv_sss        <= 0;
	 lv_falling_s  <= 0;
	 fv_falling_s  <= 0;

	 checksum      <= 0;
	 frame_cycles_count <= 0;
	 num_rows      <=0;
	 num_cols      <=0;
	 col_count     <=0;
	 row_count     <=0;
	 enable_s      <=0;
	 wait_for_fv_to_drop   <=1;
	 frame_count   <=0;
	 header_mode   <=0;
	 header_addr   <=0;
	 header_stall_s<=0;
	 left_justify_s <= 0;
	 flags_s        <= 0;
	 flags_ss       <= 0;
	 header_addr0_s <= 0;
         dvo            <= 0;
         dtypeo         <= 0;
         datao          <= 0;
      end else begin // if (!resetb_clki)
	 flags_s <= flags;
	 left_justify_s <= mode_left_justify;
	 fv_s       <= fv;
	 lv_s       <= lv;
     dv_s       <= dvi;
	 datai_s    <= datai;
	 fv_ss      <= fv_s;
	 lv_ss      <= lv_s;
     dv_ss      <= dv_s;
	 datai_ss   <= datai_s_mux;
	 fv_sss     <= fv_ss;
	 lv_falling_s  <= lv_falling;
	 fv_falling_s  <= fv_falling;
	 enable_s <= enable;
	 header_stall_s <= header_stall;
	 header_addr0_s <= header_addr[0];
	 
	 if(!enable_s || wait_for_fv_to_drop) begin
	    dvo      <= 0;
	    dtypeo   <= 0;
	    datao    <= 0;
	    checksum <= 0;
	    if(!fv_s && !fv_ss && !fv_sss) begin
	       // wait for fv to drop before moving out of the disabled state
	       // into active state to prevent an incomplete frame from
	       // entering the pipeline. We wait for all three to prevent
	       // the `DTYPE_FRAME_END from being emitted
	       wait_for_fv_to_drop <= 0;
	    end else begin
	       wait_for_fv_to_drop <= 1;
	    end
	 
	 end else if(dv) begin 
	    // Valid image data get 1st priority and trumps all other
	    // data types. We don't know yet what type of data this
	    // is, so we set it type `DTYPE_PIXEL. Later streams can
	    // deal with assigning it the correct color and whatnot.
	    dvo    <= 1;
	    dtypeo <= `DTYPE_PIXEL;
	    datao  <= datai_formatted;
	    checksum <= checksum + datai_formatted[15:0];
	 end else if(fv_rising) begin
	    // `DTYPE_FRAME_START gets second priority. Since dv
	    // is delayed one cycle beyond fv_rising, it should not
	    // be possible to miss this even though it is second
	    // priority
	    dvo    <= 1;
	    dtypeo <= `DTYPE_FRAME_START;
	    /* verilator lint_off WIDTH */
	    datao  <= frame_count;//[DATA_WIDTH-1:0];
	    /* verilator lint_on WIDTH */
	    checksum <= 0;
	 end else if(fv_falling_s) begin
	    // `DTYPE_FRAME_END get third priority. Shouldn't be able to
	    // miss this either.
	    dvo    <= 1;
	    dtypeo <= `DTYPE_FRAME_END;
	    datao  <= 0;
	    header_mode <= 1;
	    header_addr <= 0;
	    flags_ss <= flags_s;
	 end else if(lv_rising) begin
	    dvo    <= 1;
	    dtypeo <= `DTYPE_ROW_START;
	    /* verilator lint_off WIDTH */
	    datao  <= row_count;
	    /* verilator lint_on WIDTH */

	 end else if(lv_falling_s) begin
	    dvo    <= 1;
	    dtypeo <= `DTYPE_ROW_END;
	    datao  <= 0;

	 end else if(header_mode == 1) begin
	    if(header_stall_s) begin
	       dvo <= 0;
	       
	    end else begin
	       dvo <= 1;
	       header_mode <= 2;
	       header_addr <= header_addr + 1;
	    end
	    dtypeo <= `DTYPE_HEADER_START;
	    datao  <= 0;

	 end else if(header_mode == 2) begin
	    dtypeo <= `DTYPE_HEADER;
	    if(DATA_WIDTH >= 32) begin
	       header_addr <= header_addr + 1;
	       dvo <= header_addr0_s;
	       /* verilator lint_off WIDTH */
           /* verilator lint_off SELRANGE */
	       if(header_addr0_s) begin
		  datao[31:16] <= header_data;
	       end else begin
		  datao[15:0]  <= header_data;
	       end
	       /* verilator lint_on WIDTH */
           /* verilator lint_on SELRANGE */
	    end else begin
	       header_addr <= header_addr + 1;
	       dvo <= 1;
	       /* verilator lint_off WIDTH */
	       datao <= header_data;
	       /* verilator lint_on WIDTH */
	    end

	    if(header_addr >= `Image_image_data) begin
	       header_mode <= 3;
	    end

	 end else if(header_mode == 3) begin
	    dvo <= 1;
	    dtypeo <= `DTYPE_HEADER_END;
	    datao <= 0;
	    header_mode <= 0;

	 end else begin
	    dvo    <= 0;
	    datao  <= 0;
	    dtypeo <= 0;
	 end

	 if(fv_rising) begin
	    frame_count <= frame_count + 1;
	    frame_cycles_count <= 0;
	    clks_per_frame <= frame_cycles_count + 1;
	    row_count <= 0;
	 end else begin
	    frame_cycles_count <= frame_cycles_count + 1;

	    if(lv_falling) begin
	       row_count <= row_count + 1;
	    end
	 end

	 if(lv_rising) begin
	    col_count <= 0;
	 end else if(dv) begin
	    col_count <= col_count + 1;
	 end

	 if(fv_falling) begin
	    num_cols <= col_count;
	    num_rows <= row_count;
	 end

	 if(fv_s) begin
	    if(lv_rising) begin
	       clks_per_row_count <= 0;
	       clks_per_row <= clks_per_row_count + 1;
	    end else begin
	       clks_per_row_count <= clks_per_row_count + 1;
	    end
	 end

      end
   end
   
endmodule
