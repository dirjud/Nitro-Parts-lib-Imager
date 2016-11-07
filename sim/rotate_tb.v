`include "dtypes.v"

module rotate_tb
  (

   input 			  resetb,

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

   output reg 			  di_read_rdy,
   output reg [DI_DATA_WIDTH-1:0] di_reg_datao,
   output reg 			  di_write_rdy,
   output reg [15:0] 		  di_transfer_status,
   output reg 			  di_en,

   input 			  img_clk,
   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [DATA_WIDTH-1:0] 	  datai
   );


   

endmodule
