`include "terminals_defs.v"
`include "dtypes.v"
// Author: Lane Brooks
// Date: November 28, 2015

// Desc: 


module vignette
  #(parameter PIXEL_WIDTH=8,
    parameter DATA_WIDTH=16,
    parameter DI_DATA_WIDTH=32,
    parameter DIM_WIDTH=11,
    parameter NUM_ROWS=728,
    parameter NUM_COLS=1286,
    parameter GAIN_WIDTH=8,
    parameter GAIN_FRAC_WIDTH=6,
    parameter SUBSAMPLE_SHIFT=0) // 2^SUB_SAMPLE_SHIFT cols/rows gain coeff get interpolated
   (
    input                         clk,
    input                         resetb_clk, 
    input                         enable,
    
    // di interface
    input                         resetb,
    input                         di_clk,
    input [15:0]                  di_term_addr,
    input [31:0]                  di_reg_addr,
    input                         di_read_mode,
    input                         di_read_req,
    input                         di_read,
    input                         di_write_mode,
    input                         di_write,
    input [DI_DATA_WIDTH-1:0]     di_reg_datai,

    output                        di_read_rdy,
    output [DI_DATA_WIDTH-1:0]    di_reg_datao,
    output                        di_write_rdy,
    output [15:0]                 di_transfer_status,
    output                        di_en,

    input                         dvi,
    input [`DTYPE_WIDTH-1:0]      dtypei,
    input [15:0]                  datai,
    
    output reg                    dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo,
    output reg [15:0]             datao
    );

   parameter SUBSAMPLE = 1 << SUBSAMPLE_SHIFT;
   parameter SUB_NUM_COLS = ((NUM_COLS+SUBSAMPLE-1)/SUBSAMPLE);
   parameter SUB_NUM_ROWS = ((NUM_ROWS+SUBSAMPLE-1)/SUBSAMPLE);
   reg [GAIN_WIDTH-1:0] col_coeff[0:SUB_NUM_COLS-1];
   reg [GAIN_WIDTH-1:0] row_coeff[0:SUB_NUM_ROWS-1];

   wire di_col_en = di_term_addr == `TERM_VignetteCol;
   wire di_row_en = di_term_addr == `TERM_VignetteRow;
   assign di_en = di_col_en || di_row_en;
   assign di_transfer_status = 0;
   assign di_read_rdy = 1;
   assign di_write_rdy = 1;
   assign di_reg_datao = 0; // Use this to disable read and reduce a read port to RAMs.
   /* verilator lint_off WIDTH */
   //assign di_reg_datao = (di_col_en) ? col_coeff[di_reg_addr[DIM_WIDTH-1:0]] : row_coeff[di_reg_addr[DIM_WIDTH-1:0]];
   /* verilator lint_on WIDTH */
   integer idx;
   always @(posedge di_clk) begin
      if(di_en) begin
	 if(di_write) begin
	    if(di_col_en) begin
	       col_coeff[di_reg_addr] <= di_reg_datai[GAIN_WIDTH-1:0];
	    end else begin
	       row_coeff[di_reg_addr] <= di_reg_datai[GAIN_WIDTH-1:0];
	    end
	 end
      end
   end
   
   reg [DIM_WIDTH-1:0] 		   col_pos;
   reg [DIM_WIDTH-1:0] 		   row_pos;
   wire 			   valid_pixel = |(dtypei & `DTYPE_PIXEL_MASK);
   reg                             valid_pixel_s;
   
   /* verilator lint_off WIDTH */

   // interpolate the column gain
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] cx0 = col_pos[DIM_WIDTH-1:SUBSAMPLE_SHIFT];
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] cx1a = cx0+1;
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] cx1 = (cx1a >= SUB_NUM_COLS) ? cx0:cx1a;
   wire [GAIN_WIDTH-1:0] cy0 = col_coeff[cx0];
   wire [GAIN_WIDTH-1:0] cy1 = col_coeff[cx1];
   wire [SUBSAMPLE_SHIFT-1:0] cdx = col_pos[SUBSAMPLE_SHIFT-1:0];
   wire [GAIN_WIDTH:0] dcy = (cy1 > cy0) ? cy1 - cy0 : cy0 - cy1;
   wire [GAIN_WIDTH+SUBSAMPLE_SHIFT-1:0] cm = dcy * cdx;
   wire [GAIN_WIDTH-1:0] 	      cm1 = cm >> SUBSAMPLE_SHIFT;
   wire [GAIN_WIDTH-1:0] 	      cm2 = (cy1 > cy0) ? cy0 + cm1 : cy0 - cm1;
   wire [GAIN_WIDTH-1:0] 	      col_coeff_sel = cm2;

   // interpolate the row gain
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] rx0 = row_pos[DIM_WIDTH-1:SUBSAMPLE_SHIFT];
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] rx1a = rx0+1;
   wire [DIM_WIDTH-SUBSAMPLE_SHIFT-1:0] rx1 = (rx1a >= SUB_NUM_ROWS) ? rx0:rx1a;
   
   wire [GAIN_WIDTH-1:0] ry0 = row_coeff[rx0];
   wire [GAIN_WIDTH-1:0] ry1 = row_coeff[rx1];
   wire [SUBSAMPLE_SHIFT-1:0] rdx = row_pos[SUBSAMPLE_SHIFT-1:0];
   wire [GAIN_WIDTH:0] dry = (ry1 > ry0) ? ry1 - ry0 : ry0 - ry1;
   wire [GAIN_WIDTH+SUBSAMPLE_SHIFT-1:0] rm = dry * rdx;
   wire [GAIN_WIDTH-1:0] 	      rm1 = rm >> SUBSAMPLE_SHIFT;
   wire [GAIN_WIDTH-1:0] 	      rm2 = (ry1 > ry0) ? ry0 + rm1 : ry0 - rm1;
   wire [GAIN_WIDTH-1:0] 	      row_coeff_sel = rm2;
   //wire [GAIN_WIDTH-1:0] 	      row_coeff_sel = row_coeff[row_pos[DIM_WIDTH-1:SUBSAMPLE_SHIFT]];
   
   /* verilator lint_on WIDTH */
   
   reg [GAIN_WIDTH+PIXEL_WIDTH-1:0]   mult0;
   always @(posedge di_clk) begin
      valid_pixel_s <= valid_pixel;
      mult0 <= col_coeff_sel * datai[PIXEL_WIDTH-1:0];
   end
   wire [2*GAIN_WIDTH+PIXEL_WIDTH-1:0] mult1 = row_coeff_sel * mult0;

   // check for overflow and clamp to all 1's if necessary
   wire [PIXEL_WIDTH-1:0] mult2 = (|mult1[2*GAIN_WIDTH+PIXEL_WIDTH-1:PIXEL_WIDTH+2*GAIN_FRAC_WIDTH]) ? { PIXEL_WIDTH { 1'b1 }} : mult1[PIXEL_WIDTH+2*GAIN_FRAC_WIDTH-1:2*GAIN_FRAC_WIDTH];

   reg                    dvo0;
   reg                    dtypeo0;
   reg [15:0]             datao0;
   always @(posedge clk or negedge resetb_clk) begin
      if(!resetb_clk) begin
	 dvo    <= 0;
	 dtypeo <= 0;
	 dvo0   <= 0;
	 dtypeo0<= 0;
	 datao  <= 0;
	 datao0 <= 0;
	 row_pos<= 0;
	 col_pos<= 0;
      end else begin
	 dvo0    <= dvi;
	 dtypeo0 <= dtypei;
	 dvo     <= dvo0;
	 dtypeo  <= dtypeo0;
	 datao0  <= datai;
	 if(!enable) begin
	    datao  <= datao0;
	 end else if(dvi) begin
	    if (dtypei == `DTYPE_FRAME_START) begin
	       row_pos <= 0;
	    end else if (dtypei == `DTYPE_ROW_END) begin
	       row_pos <= row_pos + 1;
	    end
	    if (dtypei == `DTYPE_ROW_START) begin
	       col_pos <= 0;
	    end else if(valid_pixel) begin
	       col_pos <= col_pos + 1;
	    end
	    if(valid_pixel_s) begin
	       /* verilator lint_off WIDTH */
	       datao <= mult2;
	       /* verilator lint_on WIDTH */
	    end else begin
	       datao <= datao0;
	    end
	 end
      end
   end
endmodule


