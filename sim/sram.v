// models an async sram.

module sram
  #(ADDR_WIDTH=18,
    DATA_WIDTH=16)
   (
    input 		   ceb,
    input 		   web,
    input 		   oeb,
/* verilator lint_off UNOPTFLAT */
    inout [DATA_WIDTH-1:0] data,
/* verilator lint_on UNOPTFLAT */
    input [ADDR_WIDTH-1:0] addr);

   reg [DATA_WIDTH-1:0]   buffer[0:(1<<ADDR_WIDTH)-1];
//   reg [DATA_WIDTH-1:0]   data;

   always @(ceb, web, addr, data, oeb) begin
      if(!ceb && !web) begin
	 buffer[addr] = data;
//	 data = {DATA_WIDTH{1'bz}};
//      end else if(!ceb && !oeb) begin
//	 data = buffer[addr];
//      end else begin
//	 data = {DATA_WIDTH{1'bz}};
      end
   end

   assign data = (oeb==0 && ceb==0) ? buffer[addr] : {DATA_WIDTH{1'bz}};


   
endmodule
