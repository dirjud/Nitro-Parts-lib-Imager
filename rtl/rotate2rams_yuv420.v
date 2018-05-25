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
  #(parameter RAW_PIXEL_SHIFT=0, BLOCK_RAM=1, MAX_COLS=1288, ANGLE_WIDTH=10, ADDR_WIDTH=21, DIM_WIDTH = $clog2(MAX_COLS)) // number of LSBs to drop in raw data stream to make it 8b.
  (input clk,
   input                          resetb,
   input [15:0]                   image_type,
   input                          enable_420,
   input                          enable_rotate,
   input signed [ANGLE_WIDTH-1:0] sin_theta,
   input signed [ANGLE_WIDTH-1:0] cos_theta, 
   
   input                          dvi,
   input [`DTYPE_WIDTH-1:0]       dtypei,
   input [15:0]                   meta_datai,
   input [7:0]                    yi,
   input [7:0]                    ui,
   input [7:0]                    vi,

   output reg [DIM_WIDTH-1:0]     num_rows,
   output reg [DIM_WIDTH-1:0]     num_cols,
   output reg                     dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [31:0]              datao,

   input                          web_clkp,
   input                          web_clkn,
   output reg [ADDR_WIDTH-1:0]    addr0,
   output                         web0 /*verilator clocker*/ ,
   output reg                     oeb0,
   inout [15:0]                   ram_databus0,

   output reg [ADDR_WIDTH-1:0]    addr1,
   output                         web1 /*verilator clocker*/ ,
   output reg                     oeb1,
   inout [15:0]                   ram_databus1
   );

   reg signed [ANGLE_WIDTH-1:0] sin_theta_s, cos_theta_s, sin_theta_ss, cos_theta_ss;
   
   // Delay the stream one pipeline cycle to match that of the kernel module.
   reg [7:0] 		   y1, u1, v1;
   reg [`DTYPE_WIDTH-1:0]  dtype1, dtype2, dtype3;
   reg [15:0] 		   meta_data1, meta_data2, meta_data3;
   reg 			   dv1, dv2, dv3;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 y1         <= 0;
	 u1         <= 0;
	 v1         <= 0;
	 dtype1     <= 0;
	 meta_data1 <= 0;
	 meta_data2 <= 0;
	 meta_data3 <= 0;
	 dv1        <= 0;
	 dv2        <= 0;
	 dtype2     <= 0;
	 dv3        <= 0;
	 dtype3     <= 0;
      end else begin
	 y1         <= yi;
	 u1         <= ui;
	 v1         <= vi;
	 dtype1     <= dtypei;
	 meta_data1 <= meta_datai;
	 meta_data2 <= meta_data1;
	 meta_data3 <= meta_data2;
	 dv1        <= dvi;
	 dv2        <= dv1;
	 dtype2     <= dtype1;
	 dv3        <= dv2;
	 dtype3     <= dtype2;
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
   reg [7:0] y00_s, y00_ss;
   reg [7:0] y01_s, y01_ss;
   reg [7:0] y10_s, y10_ss;
   reg [7:0] y11_s, y11_ss;

   wire [7:0] u00 = k[0][0][15:8];
   wire [7:0] u01 = k[0][1][15:8];
   wire [7:0] u10 = k[1][0][15:8];
   wire [7:0] u11 = k[1][1][15:8];
   reg [7:0]  u00_s, u00_ss;
   reg [7:0]  u01_s, u01_ss;
   reg [7:0]  u10_s, u10_ss;
   reg [7:0]  u11_s, u11_ss;

   wire [7:0] v00 = k[0][0][7:0];
   wire [7:0] v01 = k[0][1][7:0];
   wire [7:0] v10 = k[1][0][7:0];
   wire [7:0] v11 = k[1][1][7:0];
   reg [7:0]  v00_s, v00_ss;
   reg [7:0]  v01_s, v01_ss;
   reg [7:0]  v10_s, v10_ss;
   reg [7:0]  v11_s, v11_ss;

   
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

   wire pixeli_valid = dvi && |(dtypei & `DTYPE_PIXEL_MASK);

   wire pixel_valid0 = dvo_kernel && |(dtypeo_kernel  & `DTYPE_PIXEL_MASK);
   wire frame_start  = dvo_kernel &&   dtypeo_kernel == `DTYPE_FRAME_START;
   wire frame_end    = dvo_kernel &&   dtypeo_kernel == `DTYPE_FRAME_END;
   wire row_start    = dvo_kernel &&   dtypeo_kernel == `DTYPE_ROW_START;
   wire row_end      = dvo_kernel &&   dtypeo_kernel == `DTYPE_ROW_END;
   reg  pixel_valid0_s;
   
   // Calculate the row and column phase within the image.
   reg [DIM_WIDTH-1:0] col_pos, row_pos, col_pos_s, row_pos_s;
   wire [DIM_WIDTH-1:0] next_col_pos = col_pos + 1;
   wire [DIM_WIDTH-1:0] next_row_pos = row_pos + 1;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         row_pos <= 0;
         col_pos <= 0;
         num_rows <= 720;
         num_cols <= 1280;
         sin_theta_s <= 0;
         cos_theta_s <= (1<<(ANGLE_WIDTH-2));
         sin_theta_ss <= 0;
         cos_theta_ss <= (1<<(ANGLE_WIDTH-2));
      end else begin
	 if(frame_start) begin
            row_pos <= 0;
            sin_theta_s <= sin_theta;
            cos_theta_s <= cos_theta;
            sin_theta_ss <= sin_theta_s;
            cos_theta_ss <= cos_theta_s;
	 end else if (row_end) begin
            row_pos <= next_row_pos;
	 end else if(frame_end) begin
            /* verilator lint_off WIDTH */
            num_rows <= next_row_pos & ~(32'b1);
            num_cols <= next_col_pos & ~(32'b1);
            /* verilator lint_on WIDTH */
         end

	 if(row_start) begin
            col_pos <= 0;
	 end else if(pixel_valid0) begin
            col_pos <= next_col_pos;
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
   (.cos_theta(cos_theta_s),
    .sin_theta(sin_theta_s),
    .xi({ 1'b0, col_pos, 1'b1 }),  // add 0.5
    .yi({ 1'b0, row_pos, 1'b1 }),  // add 0.5
    .num_cols({ num_cols, 1'b0 }),
    .num_rows({ num_rows, 1'b0 }),
    .xo(colCr0),
    .yo(rowCr0)
    );
   reg signed [DIM_WIDTH:0] colCr0_s, rowCr0_s;
   always @(posedge clk) begin
      colCr0_s <= colCr0;
      rowCr0_s <= rowCr0;
   end
   wire signed [DIM_WIDTH:0] colCr1_s = colCr0_s + 1;
   wire signed [DIM_WIDTH:0] rowCr1_s = rowCr0_s + 1;


   // Now we have the four integer corner coordinates for this pixel
   // in the rotated domain, we rotate them back to where it came from
   // so we can see which of these four pixels are 'serviced' by the
   // current kernel (check which pixels fall in the square of the current
   // kernel).
   wire signed [ANGLE_WIDTH-1:0] cos_neg_theta = cos_theta_s;
   wire signed [ANGLE_WIDTH-1:0] sin_neg_theta = (~(sin_theta_s)) + 1; // invert
   wire signed [ANGLE_WIDTH-1:0] cos_neg_theta_ss = cos_theta_ss;
   wire signed [ANGLE_WIDTH-1:0] sin_neg_theta_ss = (~(sin_theta_ss)) + 1; // invert
   parameter INTERP_WIDTH=4;
   wire [DIM_WIDTH+INTERP_WIDTH:0]   c0_s[0:3];
   wire [DIM_WIDTH+INTERP_WIDTH:0]   r0_s[0:3];
   wire signed [DIM_WIDTH:0]                pC_s[0:3];
   wire signed [DIM_WIDTH:0]                pR_s[0:3];
   reg signed [DIM_WIDTH:0]                 pC_ss[0:3];
   reg signed [DIM_WIDTH:0]                 pR_ss[0:3];
   assign pC_s[0] = colCr0_s;
   assign pC_s[1] = colCr1_s;
   assign pC_s[2] = colCr0_s;
   assign pC_s[3] = colCr1_s;
   assign pR_s[0] = rowCr0_s;
   assign pR_s[1] = rowCr0_s;
   assign pR_s[2] = rowCr1_s;
   assign pR_s[3] = rowCr1_s;

   wire [7:0] x0_ss[0:3];
   wire [7:0] x1_ss[0:3];
   wire [7:0] x2_ss[0:3];
   wire [INTERP_WIDTH:0] dc0_s[0:3];
   wire [INTERP_WIDTH:0] dc1_s[0:3];
   wire [INTERP_WIDTH:0] dr0_s[0:3];
   wire [INTERP_WIDTH:0] dr1_s[0:3];
   reg [INTERP_WIDTH:0] dc0_ss[0:3];
   wire [INTERP_WIDTH:0] dc1_ss[0:3];
   reg [INTERP_WIDTH:0] dr0_ss[0:3];
   wire [INTERP_WIDTH:0] dr1_ss[0:3];
   wire [3:0]            pix_en_s;
   reg [3:0]             pix_en_ss, pix_en_sss;
   genvar                idx;
   wire [DIM_WIDTH*2-1:0] waddr_row_ss[0:3];
   wire [DIM_WIDTH*2-1:0] waddr_ss[0:3];
   wire [DIM_WIDTH*2+16-1:0] wfifo_din_ss[0:3];
   reg [DIM_WIDTH*2+16-1:0] wfifo_din_sss[0:3];
   reg [7:0]  u_ave_s, u_ave_ss ,u_ave_0;
   reg [7:0]  v_ave_s, v_ave_ss ,v_ave_0;
   wire [7:0] uv_ave_ss[0:3];
   
   // x2 is the interpolated output and waddr is where it needs written
   // to (whenever pix_en is true), so stuff them into a fifo
   wire [3:0] wfifo_full, wfifo_empty, wfifo_almost_empty;
   wire [DIM_WIDTH+DIM_WIDTH+16-1:0] wfifo_dout[0:3];
   reg [3:0]                         wfifo_rd_en, wfifo_rd_en_s;

   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         pixel_valid0_s <= 0;
         col_pos_s <= 0;
         row_pos_s <= 0;
         y00_s <=  0;
         y01_s <=  0;
         y10_s <=  0;
         y11_s <=  0;
         y00_ss <= 0;
         y01_ss <= 0;
         y10_ss <= 0;
         y11_ss <= 0;
         u00_s  <= 0;
         u01_s  <= 0;
         u10_s  <= 0;
         u11_s  <= 0;
         u00_ss <= 0;
         u01_ss <= 0;
         u10_ss <= 0;
         u11_ss <= 0;
         v00_s  <= 0;
         v01_s  <= 0;
         v10_s  <= 0;
         v11_s  <= 0;
         v00_ss <= 0;
         v01_ss <= 0;
         v10_ss <= 0;
         v11_ss <= 0;
               
         u_ave_s <= 0;
         u_ave_ss <= 0;
         v_ave_s <= 0;
         v_ave_ss <= 0;
      end else begin
        pixel_valid0_s <= pixel_valid0;
         col_pos_s <= col_pos;
         row_pos_s <= row_pos;
         y00_s <= y00;
         y01_s <= y01;
         y10_s <= y10;
         y11_s <= y11;
         y00_ss <= y00_s;
         y01_ss <= y01_s;
         y10_ss <= y10_s;
         y11_ss <= y11_s;
         
         u00_s  <= u00;
         u01_s  <= u01;
         u10_s  <= u10;
         u11_s  <= u11;
         u00_ss <= u00_s;
         u01_ss <= u01_s;
         u10_ss <= u10_s;
         u11_ss <= u11_s;
               
         v00_s  <= v00;
         v01_s  <= v01;
         v10_s  <= v10;
         v11_s  <= v11;
         v00_ss <= v00_s;
         v01_ss <= v01_s;
         v10_ss <= v10_s;
         v11_ss <= v11_s;
               
         u_ave_s <= u_ave;
         u_ave_ss <= u_ave_s;
         v_ave_s <= v_ave;
         v_ave_ss <= v_ave_s;
      end
   end
   
   generate
      for(idx=0; idx<4; idx=idx+1) begin
         rotate_matrix #(.IN_WIDTH(DIM_WIDTH+1),
                         .ANGLE_WIDTH(ANGLE_WIDTH),
                         .OUT_WIDTH(DIM_WIDTH+INTERP_WIDTH+1))
         rotate_matrix1
              (.cos_theta(cos_neg_theta),
               .sin_theta(sin_neg_theta),
               .xi(pC_s[idx]),
               .yi(pR_s[idx]),
               .num_cols(num_cols),
               .num_rows(num_rows),
               .xo(c0_s[idx]),
               .yo(r0_s[idx])
               );

         assign pix_en_s[idx] = (c0_s[idx][DIM_WIDTH+INTERP_WIDTH-1:INTERP_WIDTH] == col_pos_s) && (r0_s[idx][DIM_WIDTH+INTERP_WIDTH-1:INTERP_WIDTH] == row_pos_s) && (pC_s[idx] >= 0) && (pR_s[idx] >= 0) && (pC_s[idx] < {1'b0, num_cols}) && (pR_s[idx] < {1'b0, num_rows}) && pixel_valid0_s; // check if pixel is in valid range

         // generate the weighting factors for each corner of the kernel
         assign dc0_s[idx] = { 1'b0, c0_s[idx][INTERP_WIDTH-1:0] };
         assign dc1_ss[idx] = {1'b1, {INTERP_WIDTH{1'b0}}} - dc0_ss[idx];
         assign dr0_s[idx] = {1'b0, r0_s[idx][INTERP_WIDTH-1:0] };
         assign dr1_ss[idx] = {1'b1, {INTERP_WIDTH{1'b0}}} - dr0_ss[idx];

         assign waddr_row_ss[idx] = pR_ss[idx] * num_cols;
         /* verilator lint_off WIDTH */
         assign waddr_ss[idx] = waddr_row_ss[idx] + pC_ss[idx];
         /* verilator lint_on WIDTH */

         assign uv_ave_ss[idx] = pC_ss[idx][0] ? v00_ss : u00_s;
         assign wfifo_din_ss[idx] = { waddr_ss[idx], x2_ss[idx], uv_ave_ss[idx] };


         always @(posedge clk or negedge resetb) begin
            if(!resetb) begin
               dc0_ss[idx] <= 0;
               //dc1_ss[idx] <= 0;
               dr0_ss[idx] <= 0;
               //dr1_ss[idx] <= 0;
               pR_ss[idx] <= 0;
               pC_ss[idx] <= 0;
            end else begin
               dc0_ss[idx] <= dc0_s[idx];
               //dc1_ss[idx] <= dc1_s[idx];
               dr0_ss[idx] <= dr0_s[idx];
               //dr1_ss[idx] <= dr1_s[idx];
               pR_ss[idx] <= pR_s[idx];
               pC_ss[idx] <= pC_s[idx];
            end
         end
         // weight each corner for the kernel
         weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
         weighted_ave_cols0
           (.A0(y00_ss),
            .W0(dc1_ss[idx]),
            .A1(y01_ss),
            .W1(dc0_ss[idx]),
            .Z(x0_ss[idx]));
         weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
         weighted_ave_cols1
           (.A0(y10_ss),
            .W0(dc1_ss[idx]),
            .A1(y11_ss),
            .W1(dc0_ss[idx]),
            .Z(x1_ss[idx]));
         weighted_ave #(.DATA_WIDTH(8), .MULT_WIDTH(INTERP_WIDTH+1))
         weighted_ave_rows
           (.A0(x0_ss[idx]),
            .W0(dr1_ss[idx]),
            .A1(x1_ss[idx]),
            .W1(dr0_ss[idx]),
            .Z(x2_ss[idx]));
         

         always @(posedge clk or negedge resetb) begin
            if(!resetb) begin
               pix_en_ss[idx] <= 0;
               pix_en_sss[idx] <= 0;
               wfifo_din_sss[idx] <= 0;
            end else begin
               pix_en_ss[idx] <= pix_en_s[idx];
               pix_en_sss[idx] <= pix_en_ss[idx];
               wfifo_din_sss[idx] <= wfifo_din_ss[idx];
            end
         end

         rotate_fifo wfifo
           (
            .clk(clk),      // input wire clk
            .srst(!resetb),    // input wire srst
            .din(wfifo_din_sss[idx]),      // input wire [37 : 0] din
            .wr_en(pix_en_sss[idx]),  // input wire wr_en
            .rd_en(wfifo_rd_en[idx]),  // input wire rd_en
            .dout(wfifo_dout[idx]),    // output wire [37 : 0] dout
            .full(wfifo_full[idx]),    // output wire full
            .empty(wfifo_empty[idx]),  // output wire empty
            .almost_empty(wfifo_almost_empty[idx])
            );
      end
   endgenerate
 
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
   reg [DIM_WIDTH*2+16-1:0] ram_data_, ram_data__;
   reg                      ram_data_en;
   reg [15:0]               ram_data0, ram_data1;
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         wfifo_rd_en <= 0;
         wfifo_rd_en_s <= 0;
         ram_data_en <= 0;
         ram_data_ <= 0;
         ram_data0 <= 0;
         ram_data1 <= 0;
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
         ram_data0 <=  ram_data_[15:0];
         ram_data1 <=  ram_data_[15:0];
      end
   end
   wire [DIM_WIDTH*2-1:0] ram_waddr = ram_data_[DIM_WIDTH*2+16-1:16];

   reg 			  web0_internal, web1_internal;
   reg 			  oeb0_internal, oeb1_internal;
   wire [15:0] 		 sram_datai0, sram_datai1;
   reg 	frame_count; // toggles every frame to swap the read/write buffers
   reg [15:0] 			 ram_databus0s, ram_databus1s;
   always @(posedge clk) begin
      ram_databus0s <= sram_datai0;
      ram_databus1s <= sram_datai1;
   end
   reg 	      dvo_rot1, dvo_rot2, oeb0s, oeb1s, ob, dvo_rot;
   reg [`DTYPE_WIDTH-1:0] dtypeo_rot1, dtypeo_rot2, dtypeo_rot;
   reg [15:0]             datao_rot, datao_rot0, datao_rot1;
   reg [7:0]              datao_rot_s;
   reg  [ADDR_WIDTH-1:0]  raddr;
   wire [ADDR_WIDTH-1:0]  next_raddr = raddr + 1;
   reg [DIM_WIDTH-1:0] col_pos2, row_pos2;
   wire signed [DIM_WIDTH:0]  col_pos3, row_pos3;
   wire                       out_of_bounds = (col_pos2 >= num_cols-2) || (row_pos2 >= num_rows-2) || (col_pos3 >= {1'b0, num_cols-1}) || (row_pos3 >= {1'b0, num_rows-1}) || (col_pos3 <= 1) || (row_pos3 <= 1);

   rotate_matrix #(.IN_WIDTH(DIM_WIDTH+1),
                   .ANGLE_WIDTH(ANGLE_WIDTH),
                   .OUT_WIDTH(DIM_WIDTH+1))
   rotate_matrix_ob
     (.cos_theta(cos_neg_theta_ss),
      .sin_theta(sin_neg_theta_ss),
      .xi({1'b0, col_pos2 }),
      .yi({1'b0, row_pos2 }),
      .num_cols(num_cols),
      .num_rows(num_rows),
      .xo(col_pos3),
      .yo(row_pos3)
      );
   
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 oeb0 <= 1;
	 oeb1 <= 1;
	 oeb0_internal <= 1;
	 oeb1_internal <= 1;
	 addr0 <= 0;
	 addr1 <= 0;
	 web0_internal <= 1;
	 web1_internal <= 1;
	 frame_count <= 0;
         dvo_rot <= 0;
	 dvo_rot1 <= 0;
	 dvo_rot2 <= 0;
         dtypeo_rot  <= 0;
	 dtypeo_rot1 <= 0;
	 dtypeo_rot2 <= 0;
	 oeb1s <= 0;
	 oeb0s <= 0;
	 //ob0 <= 0;
	 ob <= 0;
         datao_rot0 <= 0;
         datao_rot1 <= 0;
         raddr <= 0;
         datao_rot_s <= 0;
      end else begin
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
	 dvo_rot1 <= dvo_kernel;
	 dvo_rot2 <= dvo_rot1;
	 dvo_rot  <= dvo_rot2;

	 dtypeo_rot1 <= dtypeo_kernel;
	 dtypeo_rot2 <= dtypeo_rot1;
	 dtypeo_rot  <= dtypeo_rot2;

	 oeb0s <= oeb0_internal;
	 oeb1s <= oeb1_internal;

	 ob <= out_of_bounds;
	 //ob <= ob0;
	 if(!enable_rotate) begin
	    oeb0  <= 1;
	    oeb1  <= 1;
	    oeb0_internal  <= 1;
	    oeb1_internal  <= 1;
	    web0_internal  <= 1;
	    web1_internal  <= 1;
	    addr0 <= 0;
	    addr1 <= 0;
            raddr <= 0;
	 end else begin
            if(oeb0s == 0) begin
	       datao_rot <= (ob) ? 128 : ram_databus0s;
	    end else if(oeb1s == 0) begin
	       datao_rot <= (ob) ? 128 : ram_databus1s;
	    end else begin
	       datao_rot <= 16'hFFFF;//datao2;
	    end
            if(oeb0s==0 || oeb1s==0) begin // delay u channel one sample for 420 construction with u and v together in last sample of kernel
               datao_rot_s <= datao_rot[7:0];
            end
	    if(frame_start) begin
	       addr0 <= 0;
	       addr1 <= 0;
	    end else if(frame_count == 0) begin
               addr0 <= ram_waddr[ADDR_WIDTH-1:0];
	       addr1 <= raddr;
	    end else begin
               addr1 <= ram_waddr[ADDR_WIDTH-1:0];
	       addr0 <= raddr;
	    end
	    
	    if(frame_start) begin
	       frame_count <= !frame_count;
               raddr <= 0;
	    end else if(pixeli_valid) begin
	       oeb0  <= ~frame_count;
	       oeb1  <=  frame_count;
	       oeb0_internal  <= ~frame_count;
	       oeb1_internal  <=  frame_count;
               raddr <= next_raddr;
	    end else begin
	       oeb0 <= 1;
	       oeb1 <= 1;
	       oeb0_internal <= 1;
	       oeb1_internal <= 1;
	    end

            if(ram_data_en) begin
	       web0_internal  <=  frame_count;
	       web1_internal  <= ~frame_count;
            end else begin
               web0_internal <= 1;
	       web1_internal <= 1;
            end
	 end
      end
   end
   assign ram_databus0 = oeb0_internal ? ram_data0 : {16{1'bz}};
   assign ram_databus1 = oeb1_internal ? ram_data1 : {16{1'bz}};
   assign sram_datai0 = ram_databus0;
   assign sram_datai1 = ram_databus1;

   ODDR2 web0_oddr(.Q(web0), .C0(web_clkp), .C1(web_clkn), .CE(1), .D0(1), .D1(web0_internal), .R(0), .S(0));
   ODDR2 web1_oddr(.Q(web1), .C0(web_clkp), .C1(web_clkn), .CE(1), .D0(1), .D1(web1_internal), .R(0), .S(0));
   
   // synthesis attribute IOB of datao0 is "TRUE";
   // synthesis attribute IOB of datao1 is "TRUE";
   // synthesis attribute IOB of ram_databus0s is "TRUE";
   // synthesis attribute IOB of ram_databus1s is "TRUE";
   // synthesis attribute IOB of web0  is "TRUE";
   // synthesis attribute IOB of oeb0  is "TRUE";
   // synthesis attribute IOB of web1  is "TRUE";
   // synthesis attribute IOB of oeb1  is "TRUE";
   // synthesis attribute IOB of addr0 is "TRUE";
   // synthesis attribute IOB of addr1 is "TRUE";

   // synthesis attribute KEEP of web0  is "TRUE";
   // synthesis attribute KEEP of oeb0  is "TRUE";
   // synthesis attribute KEEP of web1  is "TRUE";
   // synthesis attribute KEEP of oeb1  is "TRUE";
   // synthesis attribute KEEP of addr0 is "TRUE";
   // synthesis attribute KEEP of addr1 is "TRUE";
   // synthesis attribute KEEP of web0_internal  is "TRUE";
   // synthesis attribute KEEP of oeb0_internal  is "TRUE";
   // synthesis attribute KEEP of web1_internal  is "TRUE";
   // synthesis attribute KEEP of oeb1_internal  is "TRUE";
   // synthesis attribute KEEP of addr0_internal is "TRUE";
   // synthesis attribute KEEP of addr1_internal is "TRUE";


   integer wfile, ofile, ifile, frame_cnt;
   initial begin
      wfile = $fopen("rotate.txt","w");
      ofile = $fopen("rotate_out.txt","w");
      ifile = $fopen("rotate_in.txt","w");
      frame_cnt = 0;
   end
   always @(posedge clk) begin
      if(ram_data_en) begin
         $fdisplay(wfile, "0x%x", ram_data_);
      end
      if(frame_start) begin
         $fdisplay(wfile, "START");
         $fdisplay(ofile, "START");
         $fdisplay(ifile, "START");
      end
      if(frame_end) begin
         $fdisplay(wfile, "END");
         $fdisplay(ofile, "END");
         $fdisplay(ifile, "END");
//         wfile0 = $fopen("rotate_sram0_" + frame_cnt, "w");
//         wfile1 = $fopen("rotate_sram1_" + frame_cnt, "w");
//         $fclose(wfile0);
//         $fclose(wfile1);
      end
      if(dvo && dtypeo == 8) begin
         $fdisplay(ofile, "0x%x", datao);
      end
      if(dvi && dtypei == 8) begin
         $fdisplay(ifile, "0x%x 0x%x 0x%x", yi, ui, vi);
      end
   end




   wire en_rot = enable_420 && enable_rotate;
   reg dv_, pixel_valid_, frame_start_, frame_end_, header_start_, header_valid_, header_end_, row_start_,row_end_;
   reg [`DTYPE_WIDTH-1:0] dtype_;

   always @(*) begin
`ifdef TDEBUG
      if(en_rot) begin
         dv_          = dv3 && (dtype3 != `DTYPE_PIXEL_MASK) && (dtype3 != `DTYPE_ROW_START) && (dtype3 != `DTYPE_ROW_END);
         pixel_valid_ = ram_data_en;
         dtype_       = (pixel_valid_) ? `DTYPE_PIXEL_MASK : dtype3;
         frame_start_ = dv3 &&   dtype3 == `DTYPE_FRAME_START ;
         frame_end_   = dv3 &&   dtype3 == `DTYPE_FRAME_END   ;
         header_start_= dv3 &&   dtype3 == `DTYPE_HEADER_START;
         header_valid_= dv3 &&   dtype3 == `DTYPE_HEADER      ;
         header_end_  = dv3 &&   dtype3 == `DTYPE_HEADER_END  ;
         row_start_   = dv3 &&   dtype3 == `DTYPE_ROW_START   ;
         row_end_     = dv3 &&   dtype3 == `DTYPE_ROW_END     ;
`else         
      if(en_rot) begin
         dv_          = dv3;
         dtype_       = dtype3;
         pixel_valid_ = dv3 && |(dtype3  & `DTYPE_PIXEL_MASK) ;
         frame_start_ = dv3 &&   dtype3 == `DTYPE_FRAME_START ;
         frame_end_   = dv3 &&   dtype3 == `DTYPE_FRAME_END   ;
         header_start_= dv3 &&   dtype3 == `DTYPE_HEADER_START;
         header_valid_= dv3 &&   dtype3 == `DTYPE_HEADER      ;
         header_end_  = dv3 &&   dtype3 == `DTYPE_HEADER_END  ;
         row_start_   = dv3 &&   dtype3 == `DTYPE_ROW_START   ;
         row_end_     = dv3 &&   dtype3 == `DTYPE_ROW_END     ;
`endif
      end else begin
         dv_          = dv1;
         dtype_       = dtype1;
         pixel_valid_ = dv1 && |(dtype1  & `DTYPE_PIXEL_MASK) ;
         frame_start_ = dv1 &&   dtype1 == `DTYPE_FRAME_START ;
         frame_end_   = dv1 &&   dtype1 == `DTYPE_FRAME_END   ;
         header_start_= dv1 &&   dtype1 == `DTYPE_HEADER_START;
         header_valid_= dv1 &&   dtype1 == `DTYPE_HEADER      ;
         header_end_  = dv1 &&   dtype1 == `DTYPE_HEADER_END  ;
         row_start_   = dv1 &&   dtype1 == `DTYPE_ROW_START   ;
         row_end_     = dv1 &&   dtype1 == `DTYPE_ROW_END     ;
      end
   end
   
   // Calculate the row and column phase within the image.
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
         row_pos2 <= 0;
         col_pos2 <= 0;
      end else begin
	 if(frame_start_) begin
            row_pos2 <= 0;
	 end else if (row_end_) begin
            row_pos2 <= row_pos2 + 1;
         end

	 if(row_start_) begin
            col_pos2 <= 0;
	 end else if(pixel_valid_) begin
            col_pos2 <= col_pos2 + 1;
	 end
      end
   end
   wire col_phase = col_pos2[0];
   wire row_phase = row_pos2[0];


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
   wire        flush_required = frame_end_ && (|opos);
   
   always @(*) begin
      if(flush_required) begin
	 next_obuf = obuf << (32-opos);
	 next_opos = 32;
      end else if(image_type == 0) begin // raw mode
	 next_obuf = { obuf[OBUF_WIDTH-9:0],  raw_data };
	 next_opos = opos_plus_8;
      end else if(en_rot) begin
`ifdef TDEBUG
	 next_obuf = { obuf[OBUF_WIDTH-25:0], 2'b0, ram_data_[37:16] };
	 next_opos = opos_plus_24;
`else         
         if(dump_uv) begin
	    next_obuf = { obuf[OBUF_WIDTH-25:0], datao_rot[15:8], datao_rot_s[7:0], datao_rot[7:0] };
	    next_opos = opos_plus_24;
         end else begin
            next_obuf = { obuf[OBUF_WIDTH-9:0],  datao_rot[15:8] }; // drop the u and v channels
	    next_opos = opos_plus_8;
         end
`endif         
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
   wire [15:0] meta_datao = (opos == `Image_image_type) ? image_type : 
                            (en_rot) ? meta_data3 : meta_data1;
   
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
	    dtypeo <= dtype_;
	 end

	 if(pixel_valid_ || flush_required) begin
	    obuf <= next_obuf;
	    if(next_opos >= 32) begin
	       dvo <= 1;
	       datao <= { datao1[7:0], datao1[15:8], datao1[23:16], datao1[31:24] };
	       opos <= next_opos2;
	    end else begin
	       opos <= next_opos;
	       dvo <= 0;
	    end
	    
	 end else if(frame_start_) begin
	    opos <= 0;
	    dvo <= 1;
	    
	 end else if(header_start_) begin
	    opos <= 0;
	    dvo <= 1;

	 end else if(header_valid_) begin
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
	    dvo <= dv_;
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
    
