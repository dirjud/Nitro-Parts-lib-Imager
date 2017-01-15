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
   
   output [ADDR_WIDTH-1:0] 	  addr,
   output reg 			  ceb,
   output 			  web,
   inout 			  oeb,
   inout [15:0] 		  ram_databus
   );
   wire [ADDR_WIDTH-1:0] 	 addr0 = 0;
   wire [ADDR_WIDTH-1:0] 	 addr1 = 0;

   reg [15:0] 			 ram_databus0;
   reg 				 dvo1, dvo2;
   reg [`DTYPE_WIDTH-1:0] 	 dtypeo1, dtypeo2;
   reg [15:0] 			 datao1, datao2;
   
   reg [ADDR_WIDTH-1:0] 	 raddr, waddr, raddr_base;

   wire pixel_valid0 = dvi  && |(dtypei  & `DTYPE_PIXEL_MASK);
   wire pixel_valid1 = dvo1 && |(dtypeo1 & `DTYPE_PIXEL_MASK);
   wire pixel_valid2 = dvo2 && |(dtypeo2 & `DTYPE_PIXEL_MASK);
   wire frame_start  = dvi  && dtypei == `DTYPE_FRAME_START;
   wire frame_end    = dvi  && dtypei == `DTYPE_FRAME_END;
   wire row_start    = dvi  && dtypei == `DTYPE_ROW_START;
   wire row_end      = dvi  && dtypei == `DTYPE_ROW_END;
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

   wire out_of_bounds = (col_pos3 >= {3'b0, num_cols}) || (col_pos3 < 0) || (row_pos3 >= {3'b0, num_rows}) || (row_pos3 < 0);

   // reduce to correct bitwidth
   wire [DIM_WIDTH-1:0] col_4 = col_pos3[DIM_WIDTH-1:0];
   wire [DIM_WIDTH-1:0] row_4 = row_pos3[DIM_WIDTH-1:0];

   // select same bayer phase as the input image
   wire [DIM_WIDTH-1:0] col_pos_rotated = { col_pos3[DIM_WIDTH-1:1], col_pos[0]};
   wire [DIM_WIDTH-1:0] row_pos_rotated = { row_pos3[DIM_WIDTH-1:1], row_pos[0]};
   
   /* verilator lint_off WIDTH */
   wire [ADDR_WIDTH-1:0] row_start_addr = num_cols * row_pos_rotated + raddr_base;
   /* verilator lint_on WIDTH */
   reg 			 ob, ob0;
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 ceb  <= 1;
	 dvo  <= 0;
	 dtypeo <= 0;
	 datao  <= 0;
	 ram_databus0 <= 0;
	 dvo1 <= 0;
	 dtypeo1 <= 0;
	 datao1 <= 0;
	 dvo2 <= 0;
	 dtypeo2 <= 0;
	 datao2 <= 0;
	 raddr <= 0;
	 waddr <= 0;
	 row_pos <= 0;
	 col_pos <= 0;
	 num_cols <= 1280;
	 frame_count <= 0;
	 raddr_base <= 0;
	 num_rows <= 720;
	 ob <= 0;
	 ob0 <= 0;
      end else begin
	 ram_databus0 <= sram_datai;
	 ob0 <= out_of_bounds;
	 ob <= ob0;
	 
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
	 dvo1 <= dvi;
	 dvo2 <= dvo1;
	 dvo  <= dvo2;

	 dtypeo1 <= dtypei;
	 dtypeo2 <= dtypeo1;
	 dtypeo  <= dtypeo2;

	 datao1 <= datai;
	 datao2 <= datao1;

	 if(!enable) begin
	    datao <= datao2;
	    ceb <= 1;
	 end else begin

	    if(pixel_valid0) begin
	       ceb <= 0;
	    end else begin
	       ceb <= 1;
	    end

	    if(frame_start) begin
	       waddr <= frame_count ? addr0 : addr1;
	       frame_count <= !frame_count;
	    end else if(pixel_valid0) begin
	       waddr <= waddr + 1;
	    end

	    if(frame_start) begin
	       col_pos <= 0;
	       row_pos <= 0;
	       raddr_base <= frame_count ? addr1 : addr0;
	    end else if(row_start) begin
	       col_pos <= 0;
	    end else if(pixel_valid0) begin
	       col_pos <= next_col_pos;
	    end else if(row_end) begin
	       row_pos  <= next_row_pos;
	       num_cols <= col_pos;
	    end else if(frame_end) begin
	       num_rows <= row_pos;
	    end
	    /* verilator lint_off WIDTH */
	    raddr <= row_start_addr + col_pos_rotated;
	    /* verilator lint_on WIDTH */

	    if(pixel_valid2) begin
	       datao <= (ob) ? 0 : ram_databus0;
	    end else begin
	       datao <= datao2;
	    end
	 end
      end
   end

   wire cb = ~clk;
   wire c = clk;
   ODDR2 soe(.Q(oeb), .C0(c),.C1(cb),.CE(1),.R(0),.S(0),.D0(1),.D1(0));
   ODDR2 swe(.Q(web), .C0(c),.C1(cb),.CE(1),.R(0),.S(0),.D0(0),.D1(1));
   
   ODDR2 saddr[ADDR_WIDTH-1:0]
     (.Q(addr),
      .C0(c),
      .C1(cb),
      .CE(1'b1),
      .R(1'b0),
      .S(1'b0),
      .D0(waddr),
      .D1(raddr)
      );

   //   wire oeb_buf;
   //   IOBUF soei(.IO(oeb), .O(oeb_buf), .T(0), .I(0));


//   IOBUF databus_buffer[15:0]
//     (.T(c),//oeb_buf),//c),
//      .I(datao1),
//      .O(sram_datai),
//      .IO(ram_databus));
   assign ram_databus = c ? datao1 : {16{1'bz}};
   assign sram_datai = ram_databus;
   
   // synthesis attribute IOB of datao1 is "TRUE";
   // synthesis attribute IOB of ram_databus is "TRUE";
   // synthesis attribute IOB of ram_databus0 is "TRUE";
   // synthesis attribute IOB of ceb  is "TRUE";

   
   
endmodule
   
