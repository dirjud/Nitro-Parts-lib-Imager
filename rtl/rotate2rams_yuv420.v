`include "dtypes.v"
`include "array.v"
`include "terminals_defs.v"
// Author: Lane Brooks
// Date  : 3/29/2018

// Desc : Converts yuv to yuv420 while rotating. The out is
// subsampling the u an v channels. Does not convert the stream to
// planar (YUV420p) but instead adds the UV subsampled pixels after
// the two Y pixels on every other row. In other words, the stream
// looks like this: Y00 Y01 Y02 Y03 ... Y10 Y11 U11 V11 Y12 Y13 U13
// V13 ...
//
// This module assumes the U and V component are already offset to be
// unsigned numbers.

module yuv420
  #(parameter RAW_PIXEL_SHIFT=0, //num LSBs to drop in raw stream to make it 8b.
    BLOCK_RAM=1,
    MAX_COLS=1288,
    ADDR_WIDTH=21, 
    DATA_WIDTH=24,
    ANGLE_WIDTH=10,
    DIM_WIDTH=11)
   (input                                 clk,
    input                                 resetb,
    input [15:0]                          image_type,
    input                                 enable_yuv420,
    input                                 enable_rotate,
   
    input                                 dvi,
    input [`DTYPE_WIDTH-1:0]              dtypei,
    input [15:0]                          meta_datai,
    input [7:0]                           yi,
    input [7:0]                           ui,
    input [7:0]                           vi,

    output reg                            dvo,
    output reg [`DTYPE_WIDTH-1:0]         dtypeo,
    output reg [31:0]                     datao
                                          
    input signed [ANGLE_WIDTH-1:0]        sin_theta,
    input signed [ANGLE_WIDTH-1:0]        cos_theta, 

    output reg [ADDR_WIDTH-1:0]           addr0,
    output                                web0,
    output reg                            oeb0,
    inout [15:0]                          ram_databus0,

    output reg [ADDR_WIDTH-1:0]           addr1,
    output                                web1,
    output reg                            oeb1,
    inout [15:0]                          ram_databus1
    );

   reg signed [ANGLE_WIDTH-1:0]           sin_theta_s, cos_theta_s;
   reg [ADDR_WIDTH-1:0]                   addr0_internal, addr1_internal;
   reg                                    web0_internal, web1_internal;
   reg                                    oeb0_internal, oeb1_internal;
   
   wire                                   pixel_valid0 = dvi && |(dtypei & `DTYPE_PIXEL_MASK);
   wire                                   frame_start = dvi && dtypei == `DTYPE_FRAME_START;
   wire                                   frame_end = dvi && dtypei == `DTYPE_FRAME_END;
   wire                                   row_start = dvi && dtypei == `DTYPE_ROW_START;
   wire                                   row_end = dvi && dtypei == `DTYPE_ROW_END;
   
   reg [DIM_WIDTH-1:0]                    row_pos, col_pos, num_cols, num_rows;
   wire [DIM_WIDTH-1:0]                   next_col_pos = col_pos + 1;
   wire [DIM_WIDTH-1:0]                   next_row_pos = row_pos + 1;

   wire [15:0]                            sram_datai0, sram_datai1;
   reg                                    frame_count; // toggles every frame to swap the read/write buffers

   // row/col position with respect to the center of the image
   wire signed [DIM_WIDTH-1:0]            col_pos0 = col_pos - (num_cols>>1);
   wire signed [DIM_WIDTH-1:0]            row_pos0 = row_pos - (num_rows>>1);

   // apply the matrix multiply
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0]  col_pos1 = (col_pos0 * cos_theta_s) - (row_pos0 * sin_theta_s);
   wire signed [DIM_WIDTH+ANGLE_WIDTH:0]  row_pos1 = (col_pos0 * sin_theta_s) + (row_pos0 * cos_theta_s);

   // drop extra bits but keep the extra sign bit at the top
    wire signed [DIM_WIDTH+2:0]           col_pos2 = col_pos1[DIM_WIDTH+ANGLE_WIDTH:ANGLE_WIDTH-2];
    wire signed [DIM_WIDTH+2:0]           row_pos2 = row_pos1[DIM_WIDTH+ANGLE_WIDTH:ANGLE_WIDTH-2];

   // restore origin to upper right of image
    wire signed [DIM_WIDTH+2:0]           col_pos3 = col_pos2 + {3'b0, (num_cols >> 1)};
    wire signed [DIM_WIDTH+2:0]           row_pos3 = row_pos2 + {3'b0, (num_rows >> 1)} ;

   // align to same bayer phase as the input image
    wire signed [DIM_WIDTH+2:0]           col_pos4 = { col_pos3[DIM_WIDTH+2:1], col_pos[0]};
    wire signed [DIM_WIDTH+2:0]           row_pos4 = { row_pos3[DIM_WIDTH+2:1], row_pos[0]};

   // check for out of bounds
    wire                                  out_of_bounds = (col_pos4 >= {3'b0, num_cols}) || (col_pos4 < 0) || (row_pos4 >= {3'b0, num_rows}) || (row_pos4 < 0);
// || (raddr >= (1<<19));

   // reduce to correct bitwidth
    wire [DIM_WIDTH-1:0]                  col_pos_rotated = col_pos4[DIM_WIDTH-1:0];
    wire [DIM_WIDTH-1:0]                  row_pos_rotated = row_pos4[DIM_WIDTH-1:0];

   /* verilator lint_off WIDTH */
    wire [ADDR_WIDTH-1:0]                 row_start_addr = num_cols * row_pos_rotated;
    wire [ADDR_WIDTH-1:0]                 raddr = row_start_addr + col_pos_rotated;
   /* verilator lint_on WIDTH */
//   wire [ADDR_WIDTH-1:0] raddr = frame_count == 0 ? addr0_internal : addr1_internal;

    reg [15:0]                            ram_databus0s, ram_databus1s;
    always @(posedge clk) begin
    ram_databus0s <= sram_datai0;
    ram_databus1s <= sram_datai1;
    end
    reg [15:0] datao0, datao1, datao2, datao1_internal;
    reg dvo1, dvo2, oeb0s, oeb1s, ob0, ob;
    reg [`DTYPE_WIDTH-1:0] dtypeo1, dtypeo2;
   
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
    datao1_internal <= 0;
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
    datao2 <= 0;
    datao <= 0;
    dvo <= 0;
    end else begin
	 // do a three clock cycle pipeline delay to give time to turn around
	 // data through the RAM
    dvo1 <= dvi;
    dvo2 <= dvo1;
    dvo <= dvo2;

    dtypeo1 <= dtypei;
    dtypeo2 <= dtypeo1;
    dtypeo <= dtypeo2;

    datao0 <= datai;
    datao1 <= datai;
    datao1_internal <= datai;
    datao2 <= datao1_internal;

    oeb0s <= oeb0_internal;
    oeb1s <= oeb1_internal;

    ob0 <= out_of_bounds;
    ob <= ob0;
    if(!enable) begin
    oeb0 <= 1;
    oeb1 <= 1;
    oeb0_internal <= 1;
    oeb1_internal <= 1;
	    //web0  <= 1;
	    //web1  <= 1;
    web0_internal <= 1;
    web1_internal <= 1;
    addr0 <= 0;
    addr1 <= 0;
    addr0_internal <= 0;
    addr1_internal <= 0;
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
    web0_internal <= frame_count;// || (row_pos > 409);
    web1_internal <= ~frame_count;// || (row_pos > 409);
    oeb0 <= ~frame_count;
    oeb1 <= frame_count;
    oeb0_internal <= ~frame_count;
    oeb1_internal <= frame_count;
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
    row_pos <= next_row_pos;
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
   
   
   
    endmo dul e



















   
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
      end else if(enable == 0) begin // pass all the yuv data
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
