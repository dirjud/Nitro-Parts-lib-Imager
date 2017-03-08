`include "terminals_defs.v"
`include "dtypes.v"

/*
  module gamma 

  apply a lookup table to input y value when enabled.

  
 */

module lookup_map
  #(parameter PIXEL_WIDTH=8,
    parameter DI_DATA_WIDTH=16)
  (
   input pixclk,
   input resetb,
   input enable,

   // di interface
   input                  di_clk,
   input [15:0] 		  di_term_addr,
   input [31:0] 		  di_reg_addr,
   input 		          di_read_mode,
   input 		          di_read_req,
   input 		          di_read,
   input 		          di_write_mode,
   input 		          di_write,
   input [DI_DATA_WIDTH-1:0] di_reg_datai,

   output reg 			  di_read_rdy,
   output reg [DI_DATA_WIDTH-1:0] di_reg_datao,
   output reg 			  di_write_rdy,
   output reg [15:0]      di_transfer_status,
   output reg 			  di_en,

   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [PIXEL_WIDTH-1:0] y,
   input signed [PIXEL_WIDTH-1:0] u,
   input signed [PIXEL_WIDTH-1:0] v,
   input [15:0] meta_datai,

   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [PIXEL_WIDTH-1:0] yo,
   output reg [PIXEL_WIDTH-1:0] uo,
   output reg [PIXEL_WIDTH-1:0] vo,
   output reg [15:0] meta_datao
   
   );

   wire [PIXEL_WIDTH-1:0] y_lookup;
   reg [PIXEL_WIDTH-1:0] y_s;


   // di registers
   always @(posedge di_clk) begin
    if (!resetb) begin
        di_read_rdy <= 0;
        di_reg_datao <= 0;
        di_write_rdy <= 0;
        di_transfer_status <= 0;
        di_en <= 0;
    end else begin
        if (di_term_addr == `TERM_LookupMap) begin
            di_write_rdy <= 1;
            di_en <= 1;
            di_transfer_status <= 0;
        end else begin
            di_write_rdy <= 0;
            di_en <= 0;
            di_transfer_status <= 16'hffff;
        end
       /* verilator lint_off WIDTH */
       di_reg_datao <= y_lookup;
       /* verilator lint_on WIDTH */
       di_read_rdy  <= di_read_req;
    end
   end 

   wire di_rowbuffer_we = di_write && di_term_addr == `TERM_LookupMap;
   wire [9:0] di_rowbuffer_addr = (di_write_mode || di_read_mode) && di_term_addr == `TERM_LookupMap ? di_reg_addr[9:0] : y[9:0];

   rowbuffer
     #(.ADDR_WIDTH(10),
       .PIXEL_WIDTH(PIXEL_WIDTH),
       .MAX_COLS(1024))
   rowbuffer (
    .addr(di_rowbuffer_addr),
    .we(di_rowbuffer_we),
    .clk(di_clk),
    .datai(di_reg_datai[PIXEL_WIDTH-1:0]),
    .datao(y_lookup)
   );

   always @(*) begin
      yo  = (enable) ? y_lookup : y_s;
   end

  always @(posedge pixclk or negedge resetb) begin
      if(!resetb) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 y_s        <= 0;
	 uo         <= 0;
	 vo         <= 0;
      end else begin
	 dvo        <= dvi;
	 dtypeo     <= dtypei;
	 y_s        <= y;
         uo         <= u;
         vo         <= v;
	 meta_datao <= meta_datai;
      end
   end
   

endmodule
