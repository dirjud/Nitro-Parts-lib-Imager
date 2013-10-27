module rowbuffer
  #(parameter ADDR_WIDTH=11,
    parameter PIXEL_WIDTH=10,
    parameter MAX_COLS=1288
    )
  (
   input [ADDR_WIDTH-1:0] addr,
   input we,
   input clk,
   input [PIXEL_WIDTH-1:0] datai,
   output [PIXEL_WIDTH-1:0] datao
   );

   reg [PIXEL_WIDTH-1:0]    data[0:MAX_COLS-1];
   
   always @(posedge clk) begin
      if (we) begin
	 data[addr] <= datai;
      end
   end
   assign datao = data[addr];
   
endmodule
