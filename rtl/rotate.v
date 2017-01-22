// Author: Lane Brooks
// Date: 10/19/16

// Description: Rotates image about (center_row, center_col)
// position. Uses SRAM interface and will double buffer between addr0
// and addr1 as its starting location. Set addr0 equal to addr1 for a
// single buffer situation.
// 


module rotate
  #(parameter ADDR_WIDTH=21, DATA_WIDTH=24, ANGLE_WIDTH=10, DIM_WIDTH=11)
  (input clk,
   input 			  resetb,
   input 			  enable,
   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [15:0] 		  datai,

   input signed [ANGLE_WIDTH-1:0] sin_theta,
   input signed [ANGLE_WIDTH-1:0] cos_theta, 
   output reg 			  dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [15:0] 		  datao,

//   input [ADDR_WIDTH-1:0] 	 addr0,
//   input [ADDR_WIDTH-1:0] 	 addr1,
//   input [DIM_WIDTH-1:0] 	 center_col,
//   input [DIM_WIDTH-1:0] 	 center_row,
   
   output reg [ADDR_WIDTH-1:0] 	  addr,
   output reg 			  ceb,
   output reg 			  web,
   output reg 			  oeb,
   inout [15:0] 		  ram_databus
   );

   wire clkfb, clk2x, locked, clk2x0;
   DCM_SP
     #( .CLKFX_MULTIPLY(2),
        .CLKFX_DIVIDE(1),
        .CLKIN_PERIOD(20)
        )
   doubler
   (
    .CLK0(clkfb), 
    .CLK180(),
    .CLK270(),
    .CLK2X(clk2x0),
    .CLK2X180(),
    .CLK90(),
    .CLKDV(),
    .CLKFX(),
    .CLKFX180(),
    .LOCKED(locked),
    .PSDONE(),
    .STATUS(),
    .CLKFB(clkfb),
    .CLKIN(clk),
    .DSSEN(1'b0),
    .PSCLK(1'b0),
    .PSEN(1'b0),
    .PSINCDEC(),
    .RST(!resetb)
    );
   BUFG bufg(.I(clk2x0), .O(clk2x));
   
   reg [15:0] datai_s;
   reg 	      dvi_s, dvi_ss;
   reg [`DTYPE_WIDTH-1:0] dtypei_s;
   reg 			  toggle;
   wire 		  dvi2x = dvi_s && toggle;
   always @(posedge clk2x) begin
      datai_s  <= datai;
      dvi_s    <= dvi;
      dvi_ss   <= dvi_s;
      dtypei_s <= dtypei;
   end
   wire dvi_sync = dvi_s && !dvi_ss;
   
   wire [ADDR_WIDTH-1:0] 	 addr0 = 0;
   wire [ADDR_WIDTH-1:0] 	 addr1 = 0;

   reg 				 dvo1, dvo2, dvo3, dvo2x;
   reg [`DTYPE_WIDTH-1:0] 	 dtypeo1, dtypeo2, dtypeo3, dtypeo2x;
   reg [15:0] 			 datao1, datao10, datao2, datao3, datao2x;

   always @(posedge clk) begin
      if(!enable) begin
	 dvo    <= dvi;
	 dtypeo <= dtypei;
	 datao  <= datai;
      end else begin
	 dvo    <= dvo2x;
	 dtypeo <= dtypeo2x;
	 datao  <= datao2x;
      end
   end
   
   reg [ADDR_WIDTH-1:0] 	 raddr, waddr, raddr_base;

   wire pixel_valid0 = dvi2x && |(dtypei_s  & `DTYPE_PIXEL_MASK);
   wire frame_start  = dvi2x && dtypei_s == `DTYPE_FRAME_START;
   wire frame_end    = dvi2x && dtypei_s == `DTYPE_FRAME_END;
   wire row_start    = dvi2x && dtypei_s == `DTYPE_ROW_START;
   wire row_end      = dvi2x && dtypei_s == `DTYPE_ROW_END;
   reg [DIM_WIDTH-1:0] row_pos, col_pos, num_cols, num_rows;
   wire [DIM_WIDTH-1:0] next_col_pos = col_pos + 1;
   wire [DIM_WIDTH-1:0] next_row_pos = row_pos + 1;

   wire [15:0] 		 sram_datai;
   reg 	frame_count; // toggles every frame to swap the read/write buffers

   // row/col position with respect to the center of the image
   wire signed [DIM_WIDTH-1:0] col_pos0 = col_pos - (num_cols>>1);
   wire signed [DIM_WIDTH-1:0] row_pos0 = row_pos - (num_rows>>1);

   // apply the matrix multiply
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0] col_pos1 = (col_pos0 * cos_theta) - (row_pos0 * sin_theta);
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0] row_pos1 = (col_pos0 * sin_theta) + (row_pos0 * cos_theta);

   // drop extra bits but keep the extra sign bit at the top
   wire signed [DIM_WIDTH+2:0] col_pos2 = col_pos1[DIM_WIDTH+ANGLE_WIDTH:ANGLE_WIDTH-2];
   wire signed [DIM_WIDTH+2:0] row_pos2 = row_pos1[DIM_WIDTH+ANGLE_WIDTH:ANGLE_WIDTH-2];

   // restore origin to upper right of image
   wire signed [DIM_WIDTH+2:0] col_pos3 = col_pos2 + {3'b0, (num_cols >> 1)};
   wire signed [DIM_WIDTH+2:0] row_pos3 = row_pos2 + {3'b0, (num_rows >> 1)} ;

   // align to same bayer phase as the input image
   wire signed [DIM_WIDTH+2:0] col_pos4 = { col_pos3[DIM_WIDTH+2:1], col_pos[0]};
   wire signed [DIM_WIDTH+2:0] row_pos4 = { row_pos3[DIM_WIDTH+2:1], row_pos[0]};

   // check for out of bounds
   wire out_of_bounds = (col_pos4 >= {3'b0, num_cols}) || (col_pos4 < 0) || (row_pos4 >= {3'b0, num_rows}) || (row_pos4 < 0);

   // reduce to correct bitwidth
   wire [DIM_WIDTH-1:0] col_pos_rotated = col_pos4[DIM_WIDTH-1:0];
   wire [DIM_WIDTH-1:0] row_pos_rotated = row_pos4[DIM_WIDTH-1:0];

   /* verilator lint_off WIDTH */
   wire [ADDR_WIDTH-1:0] row_start_addr = num_cols * row_pos_rotated + raddr_base;
   /* verilator lint_on WIDTH */
   reg 			 ob, ob0;
   reg 			 oeb_s;
   
   reg [15:0] 			 ram_databus0p;
   always @(posedge clk2x) begin
      ram_databus0p <= sram_datai;
   end
   reg [15:0] 			 ram_databus0n;
   always @(negedge clk2x) begin
      ram_databus0n <= sram_datai;
   end
   reg fv;
   reg web_internal, oeb0_internal;
   
   always @(posedge clk2x or negedge resetb) begin
      if(!resetb) begin
	 ceb <= 1;
	 web <= 1;
	 web_internal <= 1;
	 oeb <= 1;
	 oeb0_internal <= 1;
	 dvo2x  <= 0;
	 dtypeo2x <= 0;
	 datao2x  <= 0;
	 dvo1 <= 0;
	 dtypeo1 <= 0;
	 datao1 <= 0;
	 dvo2 <= 0;
	 dtypeo2 <= 0;
	 datao2 <= 0;
	 dvo3 <= 0;
	 dtypeo3 <= 0;
	 datao3 <= 0;
	 raddr <= 0;
	 waddr <= 0;
	 addr <= 0;
	 row_pos <= 0;
	 col_pos <= 0;
	 num_cols <= 1280;
	 frame_count <= 0;
	 raddr_base <= 0;
	 num_rows <= 720;
	 ob <= 0;
	 ob0 <= 0;
	 toggle <= 0;
	 oeb_s <= 0;
	 fv <= 0;
      end else begin
	 ob0 <= out_of_bounds;
	 ob <= ob0;
	 
	 toggle <= !toggle && !dvi_sync;
	 
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
	 dvo1 <= dvi_s;
	 dvo2 <= dvo1;
	 dvo3 <= dvo2;
	 dvo2x<= dvo3;

	 dtypeo1 <= dtypei_s;
	 dtypeo2 <= dtypeo1;
	 dtypeo3 <= dtypeo2;
	 dtypeo2x  <= dtypeo3;

	 datao1 <= datai_s;
	 datao10<= datai_s;
	 datao2 <= datao1;
	 datao3 <= datao2;
	 oeb_s <= oeb0_internal;
	 
	 if(!enable) begin
	    datao2x <= datao2;
	    ceb <= 1;
	    web <= 1;
	    web_internal <= 1;
	    oeb <= 1;
	    oeb0_internal <= 1;
	    addr <= 0;
	    fv <= 0;
	 end else begin

	    ceb <= 0;
	    if(pixel_valid0) begin
	       web <= 0;
	       web_internal <= 0;
	       addr <= waddr;
	    end else begin
	       web <= 1;
	       web_internal <= 1;
	       addr <= raddr;
	    end
	    //dubplicate oeb, web, and datao10 so that they can pack in the iob
	    oeb <= web_internal; // delay web by one to always read immediately after a write
	    oeb0_internal<= web_internal;
	    
	    if(frame_start) begin
	       waddr <= frame_count ? addr0 : addr1;
	       frame_count <= !frame_count;
	    end else if(web_internal == 0) begin
	       waddr <= waddr + 1;
	    end

	    if(frame_start) begin
	       col_pos <= 0;
	       row_pos <= 0;
	       raddr_base <= frame_count ? addr1 : addr0;
	       fv <= 1;
	    end else if(row_start) begin
	       col_pos <= 0;
	    end else if(web_internal==0) begin
	       col_pos <= next_col_pos;
	    end else if(row_end) begin
	       row_pos  <= next_row_pos;
	       num_cols <= col_pos;
	    end else if(frame_end) begin
	       num_rows <= row_pos;
	       fv <= 0;
	    end
	    /* verilator lint_off WIDTH */
	    raddr <= row_start_addr + col_pos_rotated;
	    /* verilator lint_on WIDTH */

	    if(fv) begin
	       if(oeb_s == 0) begin
		  datao2x <= (ob) ? 0 : ram_databus0p;
	       end
	    end else begin
	       datao2x <= datao3;
	    end
	 end
      end
   end
   assign ram_databus = oeb0_internal ? datao10 : {16{1'bz}};
   assign sram_datai = ram_databus;
   
   // synthesis attribute IOB of datao10 is "TRUE";
   // synthesis attribute IOB of ram_databus is "TRUE";
   // synthesis attribute IOB of ram_databus0n is "TRUE";
   // synthesis attribute IOB of ram_databus0p is "TRUE";
   // synthesis attribute IOB of ceb  is "TRUE";
   // synthesis attribute IOB of web  is "TRUE";
   // synthesis attribute IOB of oeb  is "TRUE";
   // synthesis attribute IOB of addr is "TRUE";

   
   
endmodule
