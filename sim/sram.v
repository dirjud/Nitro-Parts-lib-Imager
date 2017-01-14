// models an async sram.

module sram
  #(ADDR_WIDTH=18,
    DATA_WIDTH=16)
   (
    /* verilator lint_off UNOPTFLAT */
    input 		   ceb,
    input 		   web,
    input 		   oeb,
    inout [DATA_WIDTH-1:0] data,
    input [ADDR_WIDTH-1:0] addr);

   reg [DATA_WIDTH-1:0]   buffer[0:(1<<ADDR_WIDTH)-1];

   always @(ceb, web, addr, data) begin
      if(!ceb && !web) begin
	 buffer[addr] = data;
      end
   end

   assign data = (oeb==0 && ceb==0) ? buffer[addr] : {DATA_WIDTH{1'bz}};


   wire [DATA_WIDTH-1:0] buf0 = buffer[0];
   wire [DATA_WIDTH-1:0] buf1 = buffer[1];
   wire [DATA_WIDTH-1:0] buf2 = buffer[2];
   wire [DATA_WIDTH-1:0] buf3 = buffer[3];
   wire [DATA_WIDTH-1:0] buf4 = buffer[4];
   wire [DATA_WIDTH-1:0] buf5 = buffer[5];
   wire [DATA_WIDTH-1:0] buf6 = buffer[6];
   wire [DATA_WIDTH-1:0] buf7 = buffer[7];
   wire [DATA_WIDTH-1:0] buf8 = buffer[8];
   wire [DATA_WIDTH-1:0] buf9 = buffer[9];
   /* verilator lint_on UNOPTFLAT */
   
endmodule
