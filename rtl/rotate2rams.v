// Author: Lane Brooks
// Date: 10/19/16

// Description: Rotates image about (center_row, center_col)
// position. Uses SRAM interface and will double buffer between addr0
// and addr1 as its starting location. Set addr0 equal to addr1 for a
// single buffer situation.
// 


module rotate2rams
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

   output reg [ADDR_WIDTH-1:0] 	  addr0,
/* verilator lint_off UNOPTFLAT */
   output reg 			  web0,
/* verilator lint_on UNOPTFLAT */
   output reg 			  oeb0,
   inout [15:0] 		  ram_databus0,

   output reg [ADDR_WIDTH-1:0] 	  addr1,
/* verilator lint_off UNOPTFLAT */
   output reg 			  web1,
/* verilator lint_on UNOPTFLAT */
   output reg 			  oeb1,
   inout [15:0] 		  ram_databus1
   );
   reg signed [ANGLE_WIDTH-1:0] 	  sin_theta_s, cos_theta_s;
   
   wire pixel_valid0 = dvi && |(dtypei  & `DTYPE_PIXEL_MASK);
   wire frame_start  = dvi && dtypei == `DTYPE_FRAME_START;
   wire frame_end    = dvi && dtypei == `DTYPE_FRAME_END;
   wire row_start    = dvi && dtypei == `DTYPE_ROW_START;
   wire row_end      = dvi && dtypei == `DTYPE_ROW_END;
   
   reg [DIM_WIDTH-1:0] row_pos, col_pos, num_cols, num_rows;
   wire [DIM_WIDTH-1:0] next_col_pos = col_pos + 1;
   wire [DIM_WIDTH-1:0] next_row_pos = row_pos + 1;

   wire [15:0] 		 sram_datai0, sram_datai1;
   reg 	frame_count; // toggles every frame to swap the read/write buffers

   // row/col position with respect to the center of the image
   wire signed [DIM_WIDTH-1:0] col_pos0 = col_pos - (num_cols>>1);
   wire signed [DIM_WIDTH-1:0] row_pos0 = row_pos - (num_rows>>1);

   // apply the matrix multiply
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0] col_pos1 = (col_pos0 * cos_theta_s) - (row_pos0 * sin_theta_s);
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0] row_pos1 = (col_pos0 * sin_theta_s) + (row_pos0 * cos_theta_s);

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
   wire [ADDR_WIDTH-1:0] row_start_addr = num_cols * row_pos_rotated;
   wire [ADDR_WIDTH-1:0] raddr = row_start_addr + col_pos_rotated;
   /* verilator lint_on WIDTH */

   reg [15:0] 			 ram_databus0s, ram_databus1s;
   always @(posedge clk) begin
      ram_databus0s <= sram_datai0;
      ram_databus1s <= sram_datai1;
   end
   reg [15:0] datao0, datao1, datao2;
   reg 	      dvo1, dvo2, oeb0s, oeb1s, ob0, ob;
   reg [`DTYPE_WIDTH-1:0] dtypeo1, dtypeo2;

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 web0 <= 1;
	 oeb0 <= 1;
	 addr0 <= 0;
	 web1 <= 1;
	 oeb1 <= 1;
	 addr1 <= 0;
	 row_pos <= 0;
	 col_pos <= 0;
	 num_cols <= 1280;
	 frame_count <= 0;
	 num_rows <= 720;
	 datao0 <= 0;
	 datao1 <= 0;
	 dvo1 <= 0;
	 dtypeo1 <= 0;
	 dvo2 <= 0;
	 dtypeo2 <= 0;
	 sin_theta_s <= 0;
	 cos_theta_s <= 0;
	 oeb1s <= 0;
	 oeb0s <= 0;
	 ob0 <= 0;
	 ob <= 0;
      end else begin
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
	 dvo1 <= dvi;
	 dvo2 <= dvo1;
	 dvo  <= dvo2;

	 dtypeo1 <= dtypei;
	 dtypeo2 <= dtypeo1;
	 dtypeo  <= dtypeo2;

	 datao0 <= datai;
	 datao1 <= datai;
	 datao2 <= datao1;

	 oeb0s <= oeb0;
	 oeb1s <= oeb1;

	 ob0 <= out_of_bounds;
	 ob <= ob0;
	 if(!enable) begin
	    web0  <= 1;
	    oeb0  <= 1;
	    web1  <= 1;
	    oeb1  <= 1;
	    addr0 <= 0;
	    addr1 <= 0;
	    datao <= datao2;
	 end else begin
	    if(oeb0s == 0) begin
	       datao <= (ob) ? 0 : ram_databus0s;
	    end else if(oeb1s == 0) begin
	       datao <= (ob) ? 0 : ram_databus1s;
	    end else begin
	       datao <= datao2;
	    end

	    if(frame_start) begin
	       addr0 <= 0;
	       addr1 <= 0;
	       sin_theta_s <= sin_theta;
	       cos_theta_s <= cos_theta;
	    end else if(frame_count == 0) begin
	       if(!web0) begin
		  addr0 <= addr0 + 1;
	       end
	       addr1 <= raddr;
	    end else begin
	       if(!web1) begin
		  addr1 <= addr1 + 1;
	       end
	       addr0 <= raddr;
	    end
		  

	    
	    if(frame_start) begin
	       frame_count <= !frame_count;
	    end else if(pixel_valid0) begin
	       web0  <=  frame_count;
	       web1  <= ~frame_count;
	       oeb0  <= ~frame_count;
	       oeb1  <=  frame_count;
	    end else begin
	       web0 <= 1;
	       web1 <= 1;
	       oeb0 <= 1;
	       oeb1 <= 1;
	    end

	    if(frame_start) begin
	       col_pos <= 0;
	       row_pos <= 0;
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

	 end
      end
   end
   assign ram_databus0 = oeb0 ? datao0 : {16{1'bz}};
   assign ram_databus1 = oeb1 ? datao1 : {16{1'bz}};
   assign sram_datai0 = ram_databus0;
   assign sram_datai1 = ram_databus1;

   // synthesis attribute IOB of datao0 is "TRUE";
   // synthesis attribute IOB of datao1 is "TRUE";
   // synthesis attribute IOB of ram_databus0s is "TRUE";
   // synthesis attribute IOB of ram_databus1s is "TRUE";
   // synthesis attribute IOB of web0  is "TRUE";
   // synthesis attribute IOB of oeb0  is "TRUE";
   // synthesis attribute IOB of addr0 is "TRUE";

   
   
endmodule
