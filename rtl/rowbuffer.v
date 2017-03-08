module rowbuffer
  #(parameter ADDR_WIDTH=11,
    parameter PIXEL_WIDTH=10,
    parameter MAX_COLS=1288
    )
  (
   input [ADDR_WIDTH-1:0] raddr,
   input [ADDR_WIDTH-1:0] waddr,
   input we,
   input clk,
   input [PIXEL_WIDTH-1:0] datai,
   output reg [PIXEL_WIDTH-1:0] datao
   );

   reg [PIXEL_WIDTH-1:0]    data[0:MAX_COLS-1];
   
   always @(posedge clk) begin
      if (we) begin
	 data[waddr] <= datai;
      end
      datao <= data[raddr];
   end


   wire [PIXEL_WIDTH-1:0] d0 = data[0];
   wire [PIXEL_WIDTH-1:0] d1 = data[1];
   wire [PIXEL_WIDTH-1:0] d2 = data[2];
   wire [PIXEL_WIDTH-1:0] d3 = data[3];
   wire [PIXEL_WIDTH-1:0] d4 = data[4];
   
endmodule
