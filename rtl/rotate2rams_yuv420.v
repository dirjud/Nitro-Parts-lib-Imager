`include "dtypes.v"
`include "array.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date  : 5/10/2018

// Desc : Converts yuv to yuv420 while rotating. The out is
// subsampling the u an v channels. Does not convert the stream to
// planar (YUV420p) but instead adds the UV subsampled pixels after
// the two Y pixels on every other row. In other words, the stream
// looks like this: Y00 Y01 Y02 Y03 ... Y10 Y11 U11 V11 Y12 Y13 U13
// V13 ...
//
// This module assumes the U and V component are already offset to be
// unsigned numbers.

module rotate2rams_yuv420
  #(parameter RAW_PIXEL_SHIFT=0, BLOCK_RAM=1, MAX_COLS=1288) // number of LSBs to drop in raw data stream to make it 8b.
  (input clk,
   input 			 resetb,
   input [15:0] 		 image_type,
   input 			 enable_420,
   
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [15:0] 		 meta_datai,
   input [7:0] 			 yi,
   input [7:0] 			 ui,
   input [7:0] 			 vi,

   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [31:0] 		 datao

   );
   
   // Delay the stream one pipeline cycle to match that of the kernel module.
   reg [7:0] 		   y1, u1, v1;
   reg [`DTYPE_WIDTH-1:0]  dtype1;
   reg [15:0] 		   meta_data1;
   reg 			   dv1;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 y1         <= 0;
	 u1         <= 0;
	 v1         <= 0;
	 dtype1     <= 0;
	 meta_data1 <= 0;
	 dv1        <= 0;
      end else begin
	 y1         <= yi;
	 u1         <= ui;
	 v1         <= vi;
	 dtype1     <= dtypei;
	 meta_data1 <= meta_datai;
	 dv1        <= dvi;
      end
   end

   // Create a 2x2 kernel for the u and v downampling.
   localparam KERNEL_SIZE=2;
   wire dvo_kernel;
   wire [`DTYPE_WIDTH-1:0] dtypeo_kernel;
   wire [15:0]  k[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
   wire [16*KERNEL_SIZE*KERNEL_SIZE-1:0] kernel_datao;
   `UNPACK_2DARRAY(pk_idx, 16, KERNEL_SIZE, KERNEL_SIZE, k, kernel_datao)
   wire [15:0] 		   meta_datao_kernel;
   kernel #(.KERNEL_SIZE(KERNEL_SIZE),
	    .PIXEL_WIDTH(16),
	    .DATA_WIDTH(16),
	    .MAX_COLS(MAX_COLS),
	    .BLOCK_RAM(BLOCK_RAM)
	    )
   kernel
     (
      .clk(clk),
      .resetb(resetb),
      .enable(1'b1),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai( { ui, vi }),
      .meta_datai(0),
      
      .dvo(dvo_kernel),
      .meta_datao(),
      .dtypeo(dtypeo_kernel),
      .kernel_datao(kernel_datao)
      );
   // Average the u and v pixels together
   wire [8:0] u_add0 = k[0][0][15:8] + k[0][1][15:8];
   wire [8:0] u_add1 = k[1][0][15:8] + k[1][1][15:8];
   wire [9:0] u_add2 = u_add0 + u_add1;
   wire [7:0] u_ave  = u_add2[9:2]; // divider by 4
   wire [8:0] v_add0 = k[0][0][7:0] + k[0][1][7:0];
   wire [8:0] v_add1 = k[1][0][7:0] + k[1][1][7:0];
   wire [9:0] v_add2 = v_add0 + v_add1;
   wire [7:0] v_ave  = v_add2[9:2];
   
//   wire [2:0] u_count = 
//              ((k[0][0][15:8] == 0) ? 0 : 1) + 
//              ((k[0][1][15:8] == 0) ? 0 : 1) + 
//              ((k[1][0][15:8] == 0) ? 0 : 1) + 
//              ((k[1][1][15:8] == 0) ? 0 : 1);
//   wire [2:0] v_count = 
//              ((k[0][0][7:0] == 0) ? 0 : 1) + 
//              ((k[0][1][7:0] == 0) ? 0 : 1) + 
//              ((k[1][0][7:0] == 0) ? 0 : 1) + 
//              ((k[1][1][7:0] == 0) ? 0 : 1);
//   /* verilator lint_off WIDTH */
//   wire [7:0] u_ave_alt = u_add2 / u_count;
//   wire [7:0] v_ave_alt = v_add2 / v_count;
//   /* verilator lint_on WIDTH */

   // Calculate the row and column phase within the image.
   reg col_phase, row_phase;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 row_phase <= 0;
	 col_phase <= 0;
      end else begin
	 if(dv1) begin
	    if(dtype1 == `DTYPE_FRAME_START) begin
	       row_phase <= 0;
	    end else if (dtype1 == `DTYPE_ROW_END) begin
	       row_phase <= !row_phase;
	    end

	    if(dtype1 == `DTYPE_ROW_START) begin
	       col_phase <= 0;
	    end else if(|(dtype1 & `DTYPE_PIXEL_MASK)) begin
	       col_phase <= !col_phase;
	    end
	 end
      end
   end
	     

   // Generate the output stream by shifting the data into the obuf register. When it gets 32b or
   // more of data in it, we shift 32 out on the stream.
   localparam OBUF_WIDTH = 32 + 24;
   
   reg [OBUF_WIDTH-1:0] obuf;
   reg [5:0] 		opos;
   /* verilator lint_off WIDTH */
   wire [7:0] raw_data = meta_data1 >> RAW_PIXEL_SHIFT;
   /* verilator lint_on WIDTH */

   wire       dump_uv = (row_phase == 1 && col_phase == 1);
   reg [OBUF_WIDTH-1:0] next_obuf;
   reg [5:0] 		next_opos;
   wire [5:0] 		opos_plus_8  = opos + 8;
   wire [5:0] 		opos_plus_24 = opos + 24;
   wire        flush_required = dv1 && dtype1 == `DTYPE_FRAME_END && (|opos);
   
   always @(*) begin
      if(flush_required) begin
	 next_obuf = obuf << (32-opos);
	 next_opos = 32;
      end else if(image_type == 0) begin // raw mode
	 next_obuf = { obuf[OBUF_WIDTH-9:0],  raw_data };
	 next_opos = opos_plus_8;
      end else if(enable_420 == 0) begin // pass all the yuv data
	 next_obuf = { obuf[OBUF_WIDTH-25:0], y1, u1, v1  };
	 next_opos = opos_plus_24;
      end else if(dump_uv == 1) begin // time to dump the u and v subsampled channels
	 next_obuf = { obuf[OBUF_WIDTH-25:0], y1, u_ave, v_ave  };
	 next_opos = opos_plus_24;
      end else begin
         next_obuf = { obuf[OBUF_WIDTH-9:0],  y1 }; // drop the u and v channels
	 next_opos = opos_plus_8;
      end
   end

   wire [5:0]  next_opos2 = next_opos - 32;
   wire [15:0] meta_datao = (opos == `Image_image_type) ? image_type : meta_data1;
   
   /* verilator lint_off WIDTH */
   wire [31:0] datao1 = next_obuf >> next_opos2;
   /* verilator lint_on WIDTH */

   reg 	       flushed;
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 dtypeo <= 0;
	 datao <= 0;
	 obuf <= 0;
	 opos <= 0;
	 flushed <= 0;
	 
      end else begin
	 flushed <= flush_required;

	 if(flush_required) begin // if there is data in the buffer at end of frame, flush it.
	    dtypeo <= `DTYPE_PIXEL;
	 end else if (flushed) begin
	    dtypeo <= `DTYPE_FRAME_END;
	 end else begin
	    dtypeo <= dtype1;
	 end

	 if(dv1 && |(dtype1 & `DTYPE_PIXEL_MASK) || flush_required) begin
	    obuf <= next_obuf;
	    if(next_opos >= 32) begin
	       dvo <= 1;
	       datao <= { datao1[7:0], datao1[15:8], datao1[23:16], datao1[31:24] };
	       opos <= next_opos2;
	    end else begin
	       opos <= next_opos;
	       dvo <= 0;
	    end
	    
	 end else if(dv1 && dtype1 == `DTYPE_FRAME_START) begin
	    opos <= 0;
	    dvo <= 1;
	    
	 end else if(dv1 && dtype1 == `DTYPE_HEADER_START) begin
	    opos <= 0;
	    dvo <= 1;

	 end else if(dv1 && dtype1 == `DTYPE_HEADER) begin
	    opos <= opos + 1;
	    if(opos[0]) begin
	       datao[31:16] <= meta_datao;
	       dvo <= 1;
	    end else begin
	       datao[15: 0] <= meta_datao;
	       dvo <= 0;
	    end
	 end else if(flushed) begin
	    dvo <= 1;
	 end else begin
	    dvo <= dv1;
	    datao <= 0;
	 end
      end
   end
endmodule
