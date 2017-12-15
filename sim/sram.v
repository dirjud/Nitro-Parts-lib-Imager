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

`ifdef verilator

   assign data = (!ceb && !oeb) ? buffer[addr] : {DATA_WIDTH{1'bz}};
   
   always @(posedge web) begin
      if(!ceb) begin
 	 buffer[addr] = data;
      end
   end
 
//   assign data = (oeb==0 && ceb==0) ? buffer[addr] : {DATA_WIDTH{1'bz}};

`else

//   reg [DATA_WIDTH-1:0]   data;
   reg [DATA_WIDTH-1:0]   data0;
   always @(*) begin
      #1 data0 = data;
   end
   always @(*) begin
      if(!ceb && !web) begin
	 buffer[addr] = data0;
//	 data = {DATA_WIDTH{1'bz}};
//      end else if(!ceb && !oeb) begin
//	 data = buffer[addr];
//      end else begin
//	 data = {DATA_WIDTH{1'bz}};
      end
   end

   assign data = (oeb==0 && ceb==0) ? buffer[addr] : {DATA_WIDTH{1'bz}};

`endif
   
endmodule
