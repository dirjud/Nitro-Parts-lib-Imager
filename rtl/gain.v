// Description: Uses the four parameters gain00, gain01, gain10, and gain11
// to gain the four possible color channels. This can be used to apply a
// white balance to the image stream.
//
// 'gain00' is applied to even cols and rows
// 'gain01' is applied to odd cols and even rows
// 'gain10' is applied to even cols and odd rows
// 'gain11' is applied to odd cols and rows
//
// Set parameter 'GAIN_WIDTH' to the total width of the gain coefficient.
// Then set 'GAIN_FRAC_WIDTH' to the fractional width of the coeeficient.
// So if GAIN_WIDTH=12 and GAIN_FRAC_WIDTH=8, the coefficients will be
// xxxx.xxxxxxxx in terms of where the decimal point ends up.
//
// In the event of overflow, the pixel is clamped.
`include "dtypes.v"

module gain
  #(parameter GAIN_WIDTH=8,
    parameter GAIN_FRAC_WIDTH=7,
    parameter PIXEL_WIDTH=10,
    parameter DATA_WIDTH=16
    )
  (
   input 			 clk,
   input 			 resetb,
   input 			 enable,
   input [GAIN_WIDTH-1:0] 	 gain00,
   input [GAIN_WIDTH-1:0] 	 gain01,
   input [GAIN_WIDTH-1:0] 	 gain10,
   input [GAIN_WIDTH-1:0] 	 gain11,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 datai,
   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 datao
   );

   reg 				 col_phase;
   reg 				 row_phase;


   wire [GAIN_WIDTH-1:0] gain = 
			  (col_phase == 0 && row_phase == 0) ? gain00 :
			  (col_phase == 1 && row_phase == 0) ? gain01 :
			  (col_phase == 0 && row_phase == 1) ? gain10 : gain11;

   // gain
   wire [GAIN_WIDTH+PIXEL_WIDTH-1:0] data_mult0 = gain * datai[PIXEL_WIDTH-1:0];

   // check for overflow and clamp to all 1's if necessary
   wire [PIXEL_WIDTH-1:0] 	      data_mult = (|data_mult0[GAIN_WIDTH+PIXEL_WIDTH-1:PIXEL_WIDTH+GAIN_FRAC_WIDTH]) ? { PIXEL_WIDTH { 1'b1 }} : data_mult0[PIXEL_WIDTH+GAIN_FRAC_WIDTH-1:GAIN_FRAC_WIDTH];
   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 dtypeo <= 0;
	 datao <= 0;
	 col_phase <= 0;
	 row_phase <= 0;
      end else begin
	 dvo <= dvi;
	 dtypeo <= dtypei;
	 if(!enable || !dvi) begin
	    datao <= datai;
	 end else if(dvi) begin
	    if(dtypei == `DTYPE_FRAME_START) begin
	       col_phase <= 0;
	       row_phase <= 0;
	    end else if(dtypei == `DTYPE_ROW_START) begin
	       col_phase <= 0;
	       row_phase <= !row_phase;
	    end else if(dtypei == `DTYPE_PIXEL) begin
	       col_phase <= !col_phase;
	    end

	    if(dtypei == `DTYPE_PIXEL) begin
 	       /* verilator lint_off WIDTH */
	       datao <= data_mult;
 	       /* verilator lint_on WIDTH */
	    end else begin
	       datao <= datai;
	    end
	 end
      end
   end
endmodule
