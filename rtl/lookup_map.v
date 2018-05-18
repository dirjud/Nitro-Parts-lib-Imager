`include "terminals_defs.v"
`include "dtypes.v"

/*
  module gamma 

  apply a lookup table to input y value when enabled.

  
 */

module lookup_map
  #(parameter PIXEL_WIDTH=8)
  (
   input                          pixclk,
   input                          resetb_clk,
   input                          enable,

   // di interface
   input                          di_clk,
   input                          resetb,
   input [15:0]                   di_term_addr,
   input [31:0]                   di_reg_addr,
   input                          di_read_mode,
   input                          di_read_req,
   input                          di_read,
   input                          di_write_mode,
   input                          di_write,
   input [31:0]                   di_reg_datai,

   output                         di_read_rdy,
   output [31:0]                  di_reg_datao,
   output                         di_write_rdy,
   output [15:0]                  di_transfer_status,
   output                         di_en,

   input                          dvi,
   input [`DTYPE_WIDTH-1:0]       dtypei,
   input [PIXEL_WIDTH-1:0]        y,
   input signed [PIXEL_WIDTH-1:0] u,
   input signed [PIXEL_WIDTH-1:0] v,
   input [15:0]                   meta_datai,

   output reg                     dvo,
   output reg [`DTYPE_WIDTH-1:0]  dtypeo,
   output reg [PIXEL_WIDTH-1:0]   yo,
   output reg [PIXEL_WIDTH-1:0]   uo,
   output reg [PIXEL_WIDTH-1:0]   vo,
   output reg [15:0]              meta_datao
   
   );

   wire [PIXEL_WIDTH-1:0] y_lookup;

   assign di_en = di_term_addr == `TERM_LookupMap;
   assign di_transfer_status = 0;
   assign di_read_rdy = 1;
   assign di_write_rdy = 1;
   
   wire       wea  = 0;
   wire [9:0] dina = 0;

   wire   web = di_en && di_write;
   
   lookup_map_mem lookup_map_mem
     (
      .clka(pixclk),    // input wire clka
      .wea(wea),      // input wire [0 : 0] wea
      .addra(y[9:0]),  // input wire [9 : 0] addra
      .dina(dina),    // input wire [9 : 0] dina
      .douta(y_lookup),  // output wire [9 : 0] douta
      .ena(1'b1),
      
      .clkb(di_clk),             // input wire clkb
      .web(web),                 // input wire [0 : 0] web
      .addrb(di_reg_addr[9:0]),  // input wire [9 : 0] addrb
      .dinb(di_reg_datai[9:0]),  // input wire [9 : 0] dinb
      .doutb(di_reg_datao[9:0]),  // output wire [9 : 0] doutb
      .enb(1'b1)
      );
   assign di_reg_datao[31:10] = 0;

   reg    dvo0;
   reg [`DTYPE_WIDTH-1:0] dtypeo0;
   reg [PIXEL_WIDTH-1:0]  yo0, uo0, vo0;
   reg [15:0]             meta_datao0;
   reg    dvo1;
   reg [`DTYPE_WIDTH-1:0] dtypeo1;
   reg [PIXEL_WIDTH-1:0]  yo1, uo1, vo1;
   reg [15:0]             meta_datao1;
      
   always @(posedge pixclk or negedge resetb_clk) begin
      if(!resetb_clk) begin
	 dvo        <= 0;
	 dtypeo     <= 0;
	 meta_datao <= 0;
	 yo         <= 0;
	 uo         <= 0;
	 vo         <= 0;

	 dvo0        <= 0;
	 dtypeo0     <= 0;
	 meta_datao0 <= 0;
	 yo0         <= 0;
	 uo0         <= 0;
	 vo0         <= 0;

	 dvo1        <= 0;
	 dtypeo1     <= 0;
	 meta_datao1 <= 0;
	 yo1         <= 0;
	 uo1         <= 0;
	 vo1         <= 0;

      end else begin
	 dvo0        <= dvi;
	 dtypeo0     <= dtypei;
         yo0         <= y;
         uo0         <= u;
         vo0         <= v;
	 meta_datao0 <= meta_datai;

	 dvo1        <= dvo0;
	 dtypeo1     <= dtypeo0;
         yo1         <= yo0;
         uo1         <= uo0;
         vo1         <= vo0;
	 meta_datao1 <= meta_datao0;

	 dvo        <= dvo1;
	 dtypeo     <= dtypeo1;
         yo         <= (enable) ? y_lookup : yo1;
         uo         <= uo1;
         vo         <= vo1;
	 meta_datao <= meta_datao1;
      end
   end
   

endmodule
