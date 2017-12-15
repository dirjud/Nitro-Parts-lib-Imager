// Author: Lane Brooks
// Date: 10/30/2017

// Description: Rotates image about (center_row, center_col)
// position. Uses SRAM interface and two rams

`include "dtypes.v"
module rotate2rams_yuv
  #(parameter ADDR_WIDTH=21, PIXEL_WIDTH=10, ANGLE_WIDTH=10, DIM_WIDTH=11)
  (input clk,
   input                          resetb,
   input                          enable,
   input                          dvi,
   input [PIXEL_WIDTH-1:0]        yi,
   input [PIXEL_WIDTH-1:0]        ui,
   input [PIXEL_WIDTH-1:0]        vi,
   input [`DTYPE_WIDTH-1:0]       dtypei,
   input [15:0]                   meta_datai,

   input signed [ANGLE_WIDTH-1:0] sin_theta,
   input signed [ANGLE_WIDTH-1:0] cos_theta,
   output reg                     dvo,
   output reg [7:0]               yo,
   output reg [7:0]               uo,
   output reg [7:0]               vo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [15:0]              meta_datao,


   output reg [ADDR_WIDTH-1:0]    addr0,
   output                         web0,
   output reg                     oeb0,
   inout [15:0]                   ram_databus0,

   output reg [ADDR_WIDTH-1:0]    addr1,
   output                         web1,
   output reg                     oeb1,
   inout [15:0]                   ram_databus1
   );
   reg signed [ANGLE_WIDTH-1:0] 	  sin_theta_s, cos_theta_s;
   reg [ADDR_WIDTH-1:0]   addr0_internal, addr1_internal;
   reg 			  web0_internal, web1_internal;
   reg 			  oeb0_internal, oeb1_internal;
   
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

   // check for out of bounds
   wire out_of_bounds = (col_pos3 >= {3'b0, num_cols}) || (col_pos3 < 0) || (row_pos3 >= {3'b0, num_rows}) || (row_pos3 < 0);
// || (raddr >= (1<<19));

   // reduce to correct bitwidth
   wire [DIM_WIDTH-1:0] col_pos_rotated = col_pos3[DIM_WIDTH-1:0];
   wire [DIM_WIDTH-1:0] row_pos_rotated = row_pos3[DIM_WIDTH-1:0];

   /* verilator lint_off WIDTH */
   wire [ADDR_WIDTH-1:0] row_start_addr = num_cols * row_pos_rotated;
   wire [ADDR_WIDTH-1:0] raddr = row_start_addr + col_pos_rotated;
   /* verilator lint_on WIDTH */
//   wire [ADDR_WIDTH-1:0] raddr = frame_count == 0 ? addr0_internal : addr1_internal;

   reg [15:0] 			 ram_databus0s, ram_databus1s;
   always @(posedge clk) begin
      ram_databus0s <= sram_datai0;
      ram_databus1s <= sram_datai1;
   end
   reg [15:0] datao0, datao1;
   reg 	      dvo1, dvo2, oeb0s, oeb1s, ob0, ob;
   reg [`DTYPE_WIDTH-1:0] dtypeo1, dtypeo2;


   wire [PIXEL_WIDTH-1:0] uv = (col_pos[0] ^ row_pos[0]) ? vi : ui;
   wire [15:0] yuv = { yi[PIXEL_WIDTH-1:PIXEL_WIDTH-8], uv[PIXEL_WIDTH-1:PIXEL_WIDTH-8] };
   
   reg [15:0]  meta_datao1, meta_datao2;
   reg [7:0]   yo1, yo2, uo1, uo2, vo1, vo2;
   reg         colo_phase, coli_phase, coli_phase1, rowi_phase, rowi_phase1;
   wire [15:0]  ram_databus_s = (oeb0s == 0) ? ram_databus0s : ram_databus1s;

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 oeb0 <= 1;
	 oeb1 <= 1;
	 oeb0_internal <= 1;
	 oeb1_internal <= 1;
	 addr0 <= 0;
	 addr1 <= 0;
	 addr0_internal <= 0;
	 addr1_internal <= 0;
//	 web0 <= 1;
//	 web1 <= 1;
	 web0_internal <= 1;
	 web1_internal <= 1;
	 row_pos <= 0;
	 col_pos <= 0;
	 num_cols <= 1280;
	 frame_count <= 0;
	 num_rows <= 720;
	 datao0 <= 0;
	 datao1 <= 0;
	 dvo1 <= 0;
	 dtypeo <= 0;
	 dtypeo1 <= 0;
	 dvo2 <= 0;
	 dtypeo2 <= 0;
	 sin_theta_s <= 0;
	 cos_theta_s <= 0;
	 oeb1s <= 0;
	 oeb0s <= 0;
	 ob0 <= 0;
	 ob <= 0;
         yo <= 0;
         uo <= 0;
         vo <= 0;
         dvo <= 0;
         meta_datao1 <= 0;
         meta_datao2 <= 0;
         meta_datao  <= 0;
         yo1 <= 0;
         yo2 <= 0;
         uo1 <= 0;
         uo2 <= 0;
         vo1 <= 0;
         vo2 <= 0;
         colo_phase  <= 0;
         coli_phase1 <= 0;
         coli_phase  <= 0;
         rowi_phase1 <= 0;
         rowi_phase  <= 0;
      end else begin
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
	 dvo1 <= dvi;
	 dvo2 <= dvo1;
	 dvo  <= dvo2;

         meta_datao1 <= meta_datai;
         meta_datao2 <= meta_datao1;
         meta_datao  <= meta_datao2;
         
	 dtypeo1 <= dtypei;
	 dtypeo2 <= dtypeo1;
	 dtypeo  <= dtypeo2;

	 datao0 <= yuv;
	 datao1 <= yuv;
         yo1 <= yi[PIXEL_WIDTH-1:PIXEL_WIDTH-8];
         yo2 <= yo1;
         uo1 <= ui[PIXEL_WIDTH-1:PIXEL_WIDTH-8];
         uo2 <= uo1;
         vo1 <= vi[PIXEL_WIDTH-1:PIXEL_WIDTH-8];
         vo2 <= vo1;
         
	 oeb0s <= oeb0_internal;
	 oeb1s <= oeb1_internal;

	 ob0 <= out_of_bounds;
	 ob <= ob0;
	 coli_phase1 <= col_pos_rotated[0];
	 coli_phase  <= coli_phase1;
	 rowi_phase1 <= row_pos_rotated[0];
	 rowi_phase  <= rowi_phase1;
	 if(!enable) begin
	    oeb0  <= 1;
	    oeb1  <= 1;
	    oeb0_internal  <= 1;
	    oeb1_internal  <= 1;
	    //web0  <= 1;
	    //web1  <= 1;
	    web0_internal  <= 1;
	    web1_internal  <= 1;
	    addr0 <= 0;
	    addr1 <= 0;
	    addr0_internal <= 0;
	    addr1_internal <= 0;
	    yo <= yo2;
	    uo <= uo2;
	    vo <= vo2;
	 end else begin
	    if(oeb0s == 0 || oeb1s == 0) begin
               if(ob) begin
                  yo <= 0;
                  uo <= 0;
                  vo <= 0;
               end else begin
	          yo <= ram_databus_s[15:8];
                  if(coli_phase ^ rowi_phase) begin
                     vo <= ram_databus_s[7:0];
                     //uo <= 128;
                  end else begin
                     uo <= ram_databus_s[7:0];
                     //vo <= 128;
                  end
               end
               colo_phase <= !colo_phase;
	    end else begin
	       if(row_start) begin
                  colo_phase <= 0;
	          yo <= 0;
                  uo <= 0;
                  vo <= 0;
               end
	    end

	    if(frame_start) begin
	       addr0 <= 0;
	       addr1 <= 0;
	       addr0_internal <= 0;
	       addr1_internal <= 0;
	       sin_theta_s <= sin_theta;
	       cos_theta_s <= cos_theta;
	    end else if(frame_count == 0) begin
	       if(!web0_internal) begin
		  addr0 <= addr0_internal + 1;
		  addr0_internal <= addr0_internal + 1;
	       end
	       addr1 <= raddr;
	       addr1_internal <= raddr;
	    end else begin
	       if(!web1_internal) begin
		  addr1 <= addr1_internal + 1;
		  addr1_internal <= addr1_internal + 1;
	       end
	       addr0 <= raddr;
	       addr0_internal <= raddr;
	    end
		  

	    
	    if(frame_start) begin
	       frame_count <= !frame_count;
	    end else if(pixel_valid0) begin
	       //web0  <=  frame_count;
	       //web1  <= ~frame_count;
	       web0_internal  <=  frame_count;// || (row_pos > 409);
	       web1_internal  <= ~frame_count;// || (row_pos > 409);
	       oeb0  <= ~frame_count;
	       oeb1  <=  frame_count;
	       oeb0_internal  <= ~frame_count;
	       oeb1_internal  <=  frame_count;
	    end else begin
	       //web0 <= 1;
	       //web1 <= 1;
	       web0_internal <= 1;
	       web1_internal <= 1;
	       oeb0 <= 1;
	       oeb1 <= 1;
	       oeb0_internal <= 1;
	       oeb1_internal <= 1;
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
   assign ram_databus0 = oeb0_internal ? datao0 : {16{1'bz}};
   assign ram_databus1 = oeb1_internal ? datao1 : {16{1'bz}};
   assign sram_datai0 = ram_databus0;
   assign sram_datai1 = ram_databus1;

   ODDR2 web0_oddr(.Q(web0), .C0(clk), .C1(!clk), .CE(1), .D0(1), .D1(web0_internal), .R(0), .S(0));
   ODDR2 web1_oddr(.Q(web1), .C0(clk), .C1(!clk), .CE(1), .D0(1), .D1(web1_internal), .R(0), .S(0));
   
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
   
   
   
endmodule
