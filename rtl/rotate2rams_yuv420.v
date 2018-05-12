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
  #(parameter RAW_PIXEL_SHIFT=0, BLOCK_RAM=1, MAX_COLS=1288, ANGLE_WIDTH=10) // number of LSBs to drop in raw data stream to make it 8b.
  (input clk,
   input                          resetb,
   input [15:0]                   image_type,
   input                          enable_420,
   input                          enable_rotate,
   input signed [ANGLE_WIDTH-1:0] sin_theta,
   input signed [ANGLE_WIDTH-1:0] cos_theta, 
   output reg                     shadow_sync,
   
   input                          dvi,
   input [`DTYPE_WIDTH-1:0]       dtypei,
   input [15:0]                   meta_datai,
   input [7:0]                    yi,
   input [7:0]                    ui,
   input [7:0]                    vi,

   output reg                     dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [31:0]              datao

   );

   parameter DIM_WIDTH = $clog2(MAX_COLS);
   
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

   // Create the 2x2 kernel for the u and v downampling and y interp.
   localparam KERNEL_SIZE=2;
   wire dvo_kernel;
   wire [`DTYPE_WIDTH-1:0] dtypeo_kernel;
   wire [24:0]  k[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
   wire [24*KERNEL_SIZE*KERNEL_SIZE-1:0] kernel_datao;
   `UNPACK_2DARRAY(pk_idx, 24, KERNEL_SIZE, KERNEL_SIZE, k, kernel_datao)
   wire [15:0] 		   meta_datao_kernel;
   kernel #(.KERNEL_SIZE(KERNEL_SIZE),
	    .PIXEL_WIDTH(24),
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
      .datai( { yi, ui, vi }),
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
   wire [7:0] y00 = k[0][0][23:16];
   wire [7:0] y01 = k[0][1][23:16];
   wire [7:0] y10 = k[1][0][23:16];
   wire [7:0] y11 = k[1][1][23:16];
   
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


   // Calculate the row and column phase within the image.
   reg [DIM_WIDTH-1:0] col_pos, row_pos, num_rows, num_cols;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         row_pos <= 0;
         col_pos <= 0;
         num_rows <= 720;
         num_cols <= 1280;
         shadow_sync <= 0;
      end else begin
	 if(dvo_kernel) begin
	    if(dtypeo_kernel == `DTYPE_FRAME_START) begin
               row_pos <= 0;
               shadow_sync <= 1;
	    end else if (dtypeo_kernel == `DTYPE_ROW_END) begin
               row_pos <= row_pos + 1;
               shadow_sync <= 0;
	    end else if(dtypeo_kernel == `DTYPE_FRAME_END) begin
               num_rows <= row_pos + 1;
               num_cols <= col_pos + 1;
               shadow_sync <= 0;
	    end else begin
               shadow_sync <= 0;
            end

	    if(dtypeo_kernel == `DTYPE_ROW_START) begin
               col_pos <= 0;
	    end else if(|(dtypeo_kernel & `DTYPE_PIXEL_MASK)) begin
               col_pos <= col_pos + 1;
	    end
	 end
      end
   end

   

   // Rotate the current position and find integer coordinate locations
   // in the rotated domain.
   wire signed [DIM_WIDTH:0] colCr0, rowCr0;
   rotate_matrix #(.IN_WIDTH(DIM_WIDTH+2),
                   .ANGLE_WIDTH(ANGLE_WIDTH),
                   .OUT_WIDTH(DIM_WIDTH+1))
   rotate_matrix0
   (.cos_theta(cos_theta),
    .sin_theta(sin_theta),
    .xi({ 1'b0, col_pos, 1'b1 }),  // add 0.5
    .yi({ 1'b0, row_pos, 1'b1 }),  // add 0.5
    .num_cols({ num_cols, 1'b0 }),
    .num_rows({ num_rows, 1'b0 }),
    .xo(colCr0),
    .yo(rowCr0)
    );
   wire signed [DIM_WIDTH:0] colCr1 = colCr0 + 1;
   wire signed [DIM_WIDTH:0] rowCr1 = rowCr0 + 1;
   
   // Now we have the four integer corner coordinates for this pixel
   // in the rotated domain, we rotate them back to where it came from
   // so we can see which of these four pixels are 'serviced' by the
   // current kernel (check which pixels fall in the square of the current
   // kernel).
   wire signed [ANGLE_WIDTH-1:0] cos_neg_theta = cos_theta;
   wire signed [ANGLE_WIDTH-1:0] sin_neg_theta = (~(sin_theta)) + 1; // invert
   parameter INTERP_WIDTH=4;
   wire [DIM_WIDTH+INTERP_WIDTH:0]   c0[0:3];
   wire [DIM_WIDTH+INTERP_WIDTH:0]   r0[0:3];
   wire signed [DIM_WIDTH:0]                pC[0:3];
   wire signed [DIM_WIDTH:0]                pR[0:3];
   assign pC[0] = colCr0;
   assign pC[1] = colCr1;
   assign pC[2] = colCr0;
   assign pC[3] = colCr1;
   assign pR[0] = rowCr0;
   assign pR[1] = rowCr0;
   assign pR[2] = rowCr1;
   assign pR[3] = rowCr1;
   
   rotate_matrix #(.IN_WIDTH(DIM_WIDTH+1),
                   .ANGLE_WIDTH(ANGLE_WIDTH),
                   .OUT_WIDTH(DIM_WIDTH+INTERP_WIDTH+1))
   rotate_matrix1[3:0]
   (.cos_theta(cos_neg_theta),
    .sin_theta(sin_neg_theta),
    .xi(pC),
    .yi(pR),
    .num_cols(num_cols),
    .num_rows(num_rows),
    .xo(c0),
    .yo(r0)
    );
   wire [7:0] x0[0:3];
   wire [7:0] x1[0:3];
   wire [7:0] x2[0:3];
   wire [INTERP_WIDTH:0] dc0[0:3];
   wire [INTERP_WIDTH:0] dc1[0:3];
   wire [INTERP_WIDTH:0] dr0[0:3];
   wire [INTERP_WIDTH:0] dr1[0:3];
   wire [3:0]            pix_en;
   genvar                idx;
   wire [DIM_WIDTH*2-1:0] waddr_[0:3];
   wire [DIM_WIDTH*2-1:0] waddr[0:3];
   wire [DIM_WIDTH*2+16-1:0] wfifo_din[0:3];
   wire [7:0] uv_ave = (num_cols[0]) ? v_ave : u_ave;                          
   generate
      for(idx=0; idx<4; idx=idx+1) begin
         assign pix_en[idx] = (c0[idx][DIM_WIDTH+INTERP_WIDTH-1:INTERP_WIDTH] == col_pos) && (r0[idx][DIM_WIDTH+INTERP_WIDTH-1:INTERP_WIDTH] == row_pos) && (pC[idx] >= 0) && (pR[idx] >= 0) && (pC[idx] < {1'b0, num_cols}) && (pR[idx] < {1'b0, num_rows}) && dvo_kernel && (|(dtypeo_kernel & `DTYPE_PIXEL_MASK)); // check if pixel is in valid range

         // generate the weighting factors for each corner of the kernel
         assign dc0[idx] = { 1'b0, c0[idx][INTERP_WIDTH-1:0] };
         assign dc1[idx] = {1'b1, {INTERP_WIDTH{1'b0}}} - dc0[idx];
         assign dr0[idx] = {1'b0, r0[idx][INTERP_WIDTH-1:0] };
         assign dr1[idx] = {1'b1, {INTERP_WIDTH{1'b0}}} - dr0[idx];
         assign waddr_[idx] = pR[idx] * num_cols;
         /* verilator lint_off WIDTH */
         assign waddr[idx] = waddr_[idx] + pC[idx];
         /* verilator lint_on WIDTH */
         assign wfifo_din[idx] = { waddr[idx], x2[idx], uv_ave };
      end
   endgenerate

   // weight each corner for the kernel
   weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
   weighted_ave_cols0[3:0]
     (.A0(y00),
      .W0(dc1),
      .A1(y01),
      .W1(dc0),
      .Z(x0));
   weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
   weighted_ave_cols1[3:0]
     (.A0(y10),
      .W0(dc1),
      .A1(y11),
      .W1(dc0),
      .Z(x1));
   weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
   weighted_ave_rows[3:0]
     (.A0(x0),
      .W0(dr1),
      .A1(x1),
      .W1(dr0),
      .Z(x2));

   
   
   // x2 is the interpolated output and waddr is where it needs written
   // to (whenever pix_en is true), so stuff them into a fifo
   wire [3:0] wfifo_full, wfifo_empty, wfifo_almost_empty;
   wire [DIM_WIDTH+DIM_WIDTH+16-1:0] wfifo_dout[0:3];
   reg [3:0]                         wfifo_rd_en, wfifo_rd_en_s;
   
   rotate2ram_yuv420_fifo wfifo[3:0]
     (
      .clk(clk),      // input wire clk
      .srst(!resetb),    // input wire srst
      .din(wfifo_din),      // input wire [37 : 0] din
      .wr_en(pix_en),  // input wire wr_en
      .rd_en(wfifo_rd_en),  // input wire rd_en
      .dout(wfifo_dout),    // output wire [37 : 0] dout
      .full(wfifo_full),    // output wire full
      .empty(wfifo_empty),  // output wire empty
      .almost_empty(wfifo_almost_empty)
      );
 
   // clock pixels out of the 4 wfifos in a round robin fashion and
   // into the external SRAM
   reg [1:0] wpos0;
   wire [1:0] wpos1 = wpos0 + 1;
   wire [1:0] wpos2 = wpos0 + 2;
   wire [1:0] wpos3 = wpos0 + 3;
   wire [3:0] wpos0_mask = 4'b0001 << wpos0;
   wire [3:0] wpos1_mask = 4'b0001 << wpos1;
   wire [3:0] wpos2_mask = 4'b0001 << wpos2;
   wire [3:0] wpos3_mask = 4'b0001 << wpos3;
   reg [DIM_WIDTH*2+16-1:0] ram_data_;
   reg                      ram_data_en;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         wfifo_rd_en <= 0;
         wfifo_rd_en_s <= 0;
         ram_data_en <= 0;
         ram_data_ <= 0;
         wpos0 <= 0;
      end else begin
         if(!wfifo_almost_empty[wpos0] || (!wfifo_empty[wpos0] && !wfifo_rd_en[wpos0])) begin
            wfifo_rd_en <= wpos0_mask;
         end else if(!wfifo_almost_empty[wpos1] || (!wfifo_empty[wpos1] && !wfifo_rd_en[wpos1])) begin
            wfifo_rd_en <= wpos1_mask;
         end else if(!wfifo_almost_empty[wpos2] || (!wfifo_empty[wpos2] && !wfifo_rd_en[wpos2])) begin
            wfifo_rd_en <= wpos2_mask;
         end else if(!wfifo_almost_empty[wpos3] || (!wfifo_empty[wpos3] && !wfifo_rd_en[wpos3])) begin
            wfifo_rd_en <= wpos3_mask;
         end else begin
            wfifo_rd_en <= 0;
         end 
         wpos0 <= wpos1;
         wfifo_rd_en_s <= wfifo_rd_en;
         if(|wfifo_rd_en_s) begin
            ram_data_ <= (wfifo_rd_en_s == 1) ? wfifo_dout[0] :
                         (wfifo_rd_en_s == 2) ? wfifo_dout[1] :
                         (wfifo_rd_en_s == 4) ? wfifo_dout[2] :
                         wfifo_dout[3];
            ram_data_en <= 1;
         end else begin
            ram_data_en <= 0;
         end
      end
   end
   wire [DIM_WIDTH*2-1:0] ram_waddr = ram_data_[DIM_WIDTH*2+16-1:16];
   wire [15:0]            ram_wdata = ram_data_[15:0];

   // Generate the output stream by shifting the data into the obuf
   // register. When it gets 32b or more of data in it, we shift 32
   // out on the stream.
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


module weighted_ave
  #(DATA_WIDTH=10, MULT_WIDTH=4)
   (input [DATA_WIDTH-1:0] A0,
    input [MULT_WIDTH-1:0]  W0,
    input [DATA_WIDTH-1:0]  A1,
    input [MULT_WIDTH-1:0]  W1,
    output [DATA_WIDTH-1:0] Z
    );

   wire [DATA_WIDTH+MULT_WIDTH:0] Z0 = (A0 * W0) + (A1 * W1);
   assign Z = Z0[DATA_WIDTH+MULT_WIDTH-2:MULT_WIDTH-1];
   
endmodule
    
