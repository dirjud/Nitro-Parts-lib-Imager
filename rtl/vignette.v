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
    parameter GAIN_FRAC_WIDTH=6)
   (
    input 			  clk,
    input 			  resetb,
    input 			  enable,
    
    // di interface
    input 			  di_clk,
    input [15:0] 		  di_term_addr,
    input [31:0] 		  di_reg_addr,
    input 			  di_read_mode,
    input 			  di_read_req,
    input 			  di_read,
    input 			  di_write_mode,
    input 			  di_write,
    input [DI_DATA_WIDTH-1:0] 	  di_reg_datai,

    output 			  di_read_rdy,
    output [DI_DATA_WIDTH-1:0] 	  di_reg_datao,
    output 			  di_write_rdy,
    output [15:0] 		  di_transfer_status,
    output 			  di_en,

    input 			  dvi,
    input [`DTYPE_WIDTH-1:0] 	  dtypei,
    input [15:0] 		  datai,
    
    output reg 			  dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo,
    output reg [15:0] 		  datao
    );

   reg [GAIN_WIDTH-1:0] 	   col_coeff[0:NUM_COLS-1];
   reg [GAIN_WIDTH-1:0] 	   row_coeff[0:NUM_ROWS-1];

   wire di_col_en = di_term_addr == `TERM_VignetteCol;
   wire di_row_en = di_term_addr == `TERM_VignetteRow;
   assign di_en = di_col_en || di_row_en;
   assign di_transfer_status = 0;
   assign di_read_rdy = 1;
   assign di_write_rdy = 1;
   //assign di_reg_datao = 0; // Use this to disable read and reduce a read port to RAMs.
   /* verilator lint_off WIDTH */
   assign di_reg_datao = (di_col_en) ? col_coeff[di_reg_addr[DIM_WIDTH-1:0]] : row_coeff[di_reg_addr[DIM_WIDTH-1:0]];
   /* verilator lint_on WIDTH */
   integer idx;
   always @(posedge di_clk or negedge resetb) begin
      if(!resetb) begin
	 /* verilator lint_off WIDTH */
	 for(idx=0; idx<NUM_COLS; idx=idx+1) begin
	    col_coeff[idx] = { 1'b1, { GAIN_FRAC_WIDTH { 1'b0 }}};
	 end
	 for(idx=0; idx<NUM_ROWS; idx=idx+1) begin
	    row_coeff[idx] = { 1'b1, { GAIN_FRAC_WIDTH { 1'b0 }}};
	 end
	 /* verilator lint_on WIDTH */
      end else if(di_en) begin
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

   /* verilator lint_off WIDTH */
   wire [GAIN_WIDTH-1:0] 	   col_coeff_sel = col_coeff[col_pos];
   wire [GAIN_WIDTH-1:0] 	   row_coeff_sel = row_coeff[row_pos];
   /* verilator lint_on WIDTH */
   
   wire [GAIN_WIDTH+PIXEL_WIDTH-1:0] mult0 = col_coeff_sel * datai[PIXEL_WIDTH-1:0];
   wire [2*GAIN_WIDTH+PIXEL_WIDTH-1:0] mult1 = row_coeff_sel * mult0;

   // check for overflow and clamp to all 1's if necessary
   wire [PIXEL_WIDTH-1:0] mult2 = (|mult1[2*GAIN_WIDTH+PIXEL_WIDTH-1:PIXEL_WIDTH+2*GAIN_FRAC_WIDTH]) ? { PIXEL_WIDTH { 1'b1 }} : mult1[PIXEL_WIDTH+2*GAIN_FRAC_WIDTH-1:2*GAIN_FRAC_WIDTH];
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo    <= 0;
	 dtypeo <= 0;
	 datao  <= 0;
	 row_pos<= 0;
	 col_pos<= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
	 if(!enable) begin
	    datao <= datai;
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

	    if(valid_pixel) begin
	       /* verilator lint_off WIDTH */
	       datao <= mult2;
	       /* verilator lint_on WIDTH */
	    end else begin
	       datao <= datai;
	    end
	 end
      end
   end
endmodule


