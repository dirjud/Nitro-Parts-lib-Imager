// Author: Lane Brooks
// Date: 10/19/16

// Description: Rotates image about (center_row, center_col)
// position. Uses SRAM interface and will double buffer between addr0
// and addr1 as its starting location. Set addr0 equal to addr1 for a
// single buffer situation.
// 


module rotate
  #(parameter ADDR_WIDTH=19, DATA_WIDTH=24, ANGLE_WIDTH=8)
  (input clk,
   input 			 resetb,
   input 			 enable,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 datai,

   input [ANGLE_WIDTH-1:0] 	 angle,
   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 datao,

   input 			 addr0,
   input 			 addr1,
   input [DIM_WIDTH-1:0] 	 center_col,
   input [DIM_WIDTH-1:0] 	 center_row,
   
   output reg [`ADDR_WIDTH-1:0]  addr,
   output reg 			 ceb,
   output reg 			 web,
   output reg 			 reb
   );


   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 addr <= 0;
	 ceb  <= 1;
	 web  <= 1;
	 reb  <= 1;
	 dvo  <= 0;
	 dtypeo <= 0;
	 datao  <= 0;
      end else begin
	 dvo <= dvi;
	 dtypeo <= dtypei;

	 if(!enable) begin
	    datao <= datai;
	 end else begin
	    datao <= datai;
	 end

      end
   end
endmodule
   
