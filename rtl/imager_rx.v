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

`define DTYPE_WIDTH        5

`define DTYPE_FRAME_START   0
`define DTYPE_FRAME_END     1
`define DTYPE_ROW_START     2
`define DTYPE_ROW_END       3
`define DTYPE_HEADER_START  4
`define DTYPE_HEADER_END    5

`define DTYPE_HEADER        8
`define DTYPE_PIXEL         9
`define DTYPE_PIXEL_RED    10
`define DTYPE_PIXEL_BLUE   11
`define DTYPE_PIXEL_GREEN1 12
`define DTYPE_PIXEL_GREEN2 13


module imager_rx
   #(parameter PIXEL_WIDTH=12,
     parameter DIM_WIDTH=16)
   (
    input 			  resetb,

    input 			  di_clk,
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

    input 			  clki,
    input 			  fv,
    input 			  lv,
    input [PIXEL_WIDTH-1:0] 	  datai,

    output reg 			  dvo,
    output reg [PIXEL_WIDTH-1:0]  datao,
    output reg [`DTYPE_WIDTH-1:0] dtypeo
    );
   
   reg [DIM_WIDTH-1:0] row_count, col_count;
   reg [DIM_WIDTH-1:0] num_rows, num_cols;
   reg fv_s, fv_ss, fv_sss, lv_s, lv_ss, lv_sss;
   reg [PXIEL_WIDTH-1:0] datai_s, datai_ss, datai_sss;

   // synthesis attribute IOB of fv_s  is "TRUE";
   // synthesis attribute IOB of lv_s  is "TRUE";
   // synthesis attribute IOB of datai is "TRUE";
   
   reg [31:0] frame_cycles_count;
   reg [15:0] num_rows, num_cols;
   reg [15:0] checksum;

`include "ImagerRXTerminalInstance.v"
//`include "ImageTerminalInstance.v"

   always @(posedge clki) begin
   end
   
   wire       fv_rising         = ( fv_s && !fv_ss);
   wire       fv_falling        = (!fv_s &&  fv_ss);
   wire       lv_rising         = ( lv_ss && !lv_sss);
   wire       lv_falling        = (!lv_ss &&  lv_sss);

   reg 	      lv_falling_s, lv_falling_ss, fv_falling_s, fv_falling_ss;
   
   always @(posedge clki or negedge resetb) begin
      if(!resetb) begin
	 fv_s          <= 0;
	 lv_s          <= 0;
	 datai_s       <= 0;
	 fv_ss         <= 0;
	 lv_ss         <= 0;
	 datai_ss      <= 0;
	 datai_sss     <= 0;
	 dvo_pre       <= 0;
	 lv_falling_s  <= 0;
	 lv_falling_ss <= 0;
	 fv_falling_s  <= 0;
	 fv_falling_ss <= 0;

	 checksum      <= 0;
	 frame_cycles_count <= 0;
	 num_rows      <=0;
	 num_cols      <=0;
	 col_count     <=0;
	 row_count     <=0;
      end else begin
	 fv_s       <= fv;
	 lv_s       <= lv;
	 datai_s    <= datai;
	 fv_ss      <= fv_s;
	 lv_ss      <= lv_s;
	 datai_ss   <= datai_s;
	 datai_sss  <= datai_ss;
	 dvo_pre    <= fv_ss && lv_ss;
	 lv_falling_s  <= lv_falling;
	 lv_falling_ss <= lv_falling_s;
	 fv_falling_s  <= fv_falling;
	 fv_falling_ss <= fv_falling_s;

	 if(dvo_pre) begin 
	    // Valid image data get 1st priority and trumps all other
	    // data types. We don't know yet what type of data this
	    // is, so we set it type `DTYPE_PIXEL. Later streams can
	    // deal with assigning it the correct color and whatnot.
	    dvo    <= 1;
	    dtypeo <= `DTYPE_PIXEL;
	    datao  <= datai_sss;
	    checksum <= checksum + datai_sss;
	 end else if(fv_rising) begin
	    // `DTYPE_FRAME_START gets second priority. Since dvo_pre
	    // is delayed one cycle beyond fv_rising, it should not
	    // be possible to miss this even though it is second
	    // priority
	    dvo    <= 1;
	    dtypeo <= `DTYPE_FRAME_START;
	    datao  <= 0;
	    checksum <= 0;
	 end else if(fv_falling_ss) begin
	    // `DTYPE_FRAME_END get third priority. Shouldn't be able to
	    // miss this either.
	    dvo    <= 0;
	    dtypeo <= `DTYPE_FRAME_END;
	    datao  <= 0;
	 end else if(lv_rising) begin
	    dvo    <= 1;
	    dtypeo <= `DTYPE_ROW_START;
	    datao  <= 0;
	 end else if(lv_falling_ss) begin
	    dvo    <= 1;
	    dtypeo <= `DTYPE_ROW_END;
	    datao  <= 0;
	 end

	 if(fv_rising) begin
	    frame_cycles_count <= 0;
	    clks_per_frame <= frame_cycles_count;
	    row_count <= 0;
	 end else begin
	    frame_cycles_count <= frame_cycles_count + 1;

	    if(lv_falling) begin
	       row_count <= row_count + 1;
	    end
	 end

	 if(lv_rising) begin
	    col_count <= 0;
	 end else if(dvo) begin
	    col_count <= col_count + 1;
	 end

	 if(fv_falling) begin
	    num_cols <= col_count;
	    num_rows <= row_count;
	 end
      end
   end
   
endmodule
