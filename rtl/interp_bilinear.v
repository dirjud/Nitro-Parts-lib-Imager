`include "dtypes.v"
`include "array.v"
// Author: Lane Brooks
// Date: 10/26/2013

// Desc: Bilinear interpolator of Bayer data. Set the 'phase' input to change
// color phase. This will drop a single pixel border around the image.

module interp_bilinear
  #(parameter PIXEL_WIDTH = 10,
    parameter DATA_WIDTH  = 16,
    parameter MAX_COLS    = 1288,
    parameter BLOCK_RAM   = 1
    )
  (input clk,
   input 			 resetb,
   input 			 enable,
   
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 datai,
   input [1:0] 			 phase,
   
   output reg 			 dvo,
   output reg [PIXEL_WIDTH-1:0]  r,
   output reg [PIXEL_WIDTH-1:0]  g,
   output reg [PIXEL_WIDTH-1:0]  b,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 meta_datao
   );

   parameter NUM_COLS_WIDTH = $clog2(MAX_COLS);
   localparam KERNEL_SIZE=3;
   wire dvo_kernel;
   wire [`DTYPE_WIDTH-1:0] dtypeo_kernel;
   wire [PIXEL_WIDTH-1:0]  k[0:KERNEL_SIZE-1][0:KERNEL_SIZE-1];
   wire [PIXEL_WIDTH*KERNEL_SIZE*KERNEL_SIZE-1:0] kernel_datao;
   `UNPACK_2DARRAY(pk_idx, PIXEL_WIDTH, KERNEL_SIZE, KERNEL_SIZE, k, kernel_datao)
   wire [15:0] 		   meta_datao_kernel;
   
   kernel #(.KERNEL_SIZE(KERNEL_SIZE),
	    .PIXEL_WIDTH(PIXEL_WIDTH),
	    .DATA_WIDTH(16),
	    .MAX_COLS(1288),
	    .BLOCK_RAM(BLOCK_RAM)
	    )
   kernel
     (
      .clk(clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .datai(datai[PIXEL_WIDTH-1:0]),
      .meta_datai(datai),
      
      .dvo(dvo_kernel),
      .meta_datao(meta_datao_kernel),
      .dtypeo(dtypeo_kernel),
      .kernel_datao(kernel_datao)
      );

   reg row_phase, col_phase;

   wire [PIXEL_WIDTH-1:0] kcenter      = k[1][1];
   wire [PIXEL_WIDTH+1:0] kplus_add    = {2'b0, k[0][1]} + {2'b0, k[2][1]} + {2'b0, k[1][0]} + {2'b0, k[1][2]} + 2; // add two bits at the top to prevent overflow and add 2 to round the result when the lower bits are dropped
   wire [PIXEL_WIDTH-1:0] kplus        = kplus_add[PIXEL_WIDTH+1:2];
   wire [PIXEL_WIDTH+1:0] kdiamond_add = {2'b0, k[0][0]} + {2'b0, k[2][0]} + {2'b0, k[0][2]} + {2'b0, k[2][2]} + 2;
   wire [PIXEL_WIDTH-1:0] kdiamond     = kdiamond_add[PIXEL_WIDTH+1:2];
   wire [PIXEL_WIDTH:0]   kvert_add    = k[0][1] + k[2][1] + 1;
   wire [PIXEL_WIDTH-1:0] kvert        = kvert_add[PIXEL_WIDTH:1];
   wire [PIXEL_WIDTH:0]   khorz_add    = k[1][0] + k[1][2] + 1;
   wire [PIXEL_WIDTH-1:0] khorz        = khorz_add[PIXEL_WIDTH:1];

   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 r          <= 0;
	 g          <= 0;
	 b          <= 0;
	 dtypeo     <= 0;
	 dvo        <= 0;
	 meta_datao <= 0;
	 row_phase  <= 0;
	 col_phase  <= 0;
	 
      end else begin
	 meta_datao <= meta_datao_kernel;
	 dtypeo <= dtypeo_kernel;
	 dvo <= dvo_kernel;
	 
	 if (dvo_kernel) begin
	    if(dtypeo_kernel == `DTYPE_FRAME_START) begin
	       row_phase <= phase[1];
	    end else if(dtypeo_kernel == `DTYPE_ROW_START) begin
	       col_phase <= phase[0];
	    end else if(dtypeo_kernel == `DTYPE_ROW_END) begin
	       row_phase <= !row_phase;
	    end else if(|(dtypeo_kernel  & `DTYPE_PIXEL_MASK)) begin
	       col_phase <= !col_phase;
	       case ({ row_phase, col_phase })
		  0: begin // R pixel
		     r <= kcenter;
		     g <= kplus;
		     b <= kdiamond;
		  end
		  1: begin // G1 pixel
		     r <= khorz;
		     g <= kcenter;
		     b <= kvert;
		  end
		  2: begin // G2 pixel
		     r <= kvert;
		     g <= kcenter;
		     b <= khorz;
		  end
		  3: begin // B pixel
		     r <= kdiamond;
		     g <= kplus;
		     b <= kcenter;
		  end
	       endcase
	    end
	 end
      end
   end
   
endmodule

