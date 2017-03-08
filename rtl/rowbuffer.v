module rowbuffer
  #(parameter PIXEL_WIDTH=10,
    parameter MAX_COLS=1288,
    parameter BLOCK_RAM=1,
    parameter ADDR_WIDTH=$clog2(MAX_COLS)
    )
  (
   input [ADDR_WIDTH-1:0] raddr,
   input [ADDR_WIDTH-1:0] waddr,
   input we,
   input clk,
   input [PIXEL_WIDTH-1:0] datai,
   output reg [PIXEL_WIDTH-1:0] datao
   );


   generate
      if(BLOCK_RAM==1) begin

	 (* RAM_STYLE="BLOCK" *)
	 reg [PIXEL_WIDTH-1:0]    data[0:MAX_COLS-1];
	 always @(posedge clk) begin
	    if (we) begin
	       data[waddr] <= datai;
	    end
	    datao <= data[raddr];
	 end

      end else begin

	 (* RAM_STYLE="DISTRIBUTED" *)
	 reg [PIXEL_WIDTH-1:0]    data[0:MAX_COLS-1];
	 always @(posedge clk) begin
	    if (we) begin
	       data[waddr] <= datai;
	    end
	 end
	 wire [PIXEL_WIDTH-1:0] datao_p = data[raddr];
	 always @(posedge clk) begin
	    datao <= datao_p;
	 end
//	 assign datao = data[raddr];
      end
   endgenerate
   
endmodule
