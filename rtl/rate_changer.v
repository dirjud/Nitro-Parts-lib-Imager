module rate_changer
  #(parameter DATA_WIDTH=16,
    parameter LOG2_FIFO_DEPTH=5)
  (
   input resetb,

   input clki,
   input dvi,
   input [`DTYPE_WIDTH-1:0] dtypei,
   input [DATA_WIDTH-1:0] datai,

   input clko,
   output reg dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] datao
   );


   wire 		       empty, full;
   wire [LOG2_FIFO_DEPTH-1:0]  rUsedSpace;
   wire 		       almost_empty = rUsedSpace < 2;
   wire 		       dv = (almost_empty) ? !empty && !dvo : 1;
   wire [DATA_WIDTH-1:0]       datao_pre;
   wire [`DTYPE_WIDTH-1:0]     dtypeo_pre;
   
   rate_changerFifoDualClk #(.ADDR_WIDTH(LOG2_FIFO_DEPTH),
			     .DATA_WIDTH(DATA_WIDTH + `DTYPE_WIDTH))
   fifo
     (
      .wclk(clki),
      .rclk(clko), 
      .we(dvi),
      .re(dv),
      .resetb(resetb),
      .flush(1'b0),
      .full(full),
      .empty(empty),
      .wdata( { datai,     dtypei } ),
      .rdata( { datao_pre, dtypeo_pre } ),
      .wFreeSpace(),
      .rUsedSpace(rUsedSpace)
      );
   

   always @(posedge clko or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 dtypeo <= 0;
	 datao <= 0;
      end else begin
	 dvo <= dv;
	 datao <= datao_pre;
	 dtypeo <= dtypeo_pre;
      end
   end
   
   
endmodule



///////////////////////////////////////////////////////////////////////////////
module rate_changerFifoDualClk #(parameter ADDR_WIDTH=4, DATA_WIDTH=8)
   (
    input wclk,
    input rclk, 
    input we,
    input re,
    input resetb,
    input flush,
    output full,
    output empty,
    input  [DATA_WIDTH-1:0] wdata,
    output [DATA_WIDTH-1:0] rdata,
    output [ADDR_WIDTH-1:0] wFreeSpace,
    output [ADDR_WIDTH-1:0] rUsedSpace
    );

   wire reset = !resetb | flush;

   reg [ADDR_WIDTH-1:0]    waddr, raddr, nextWaddr;
   wire [ADDR_WIDTH-1:0]   nextRaddr = raddr + 1;
   wire [ADDR_WIDTH-1:0]   raddr_pre;
   reg [ADDR_WIDTH-1:0]    raddr_ss;

   assign full       = (nextWaddr == raddr_ss);
   assign wFreeSpace = raddr_ss - nextWaddr;

   always @(posedge wclk) begin
      raddr_ss  <= raddr;
   end
      
   always @(posedge wclk or posedge reset) begin
      if(reset) begin
	 waddr      <= 0;
	 nextWaddr  <= 1;
      end else begin
	 if(we) begin
`ifdef SIM	    
	    if(full) $display("%m(%t) Writing to fifo when full.",$time);
`endif	    
	    waddr     <= nextWaddr;
	    nextWaddr <= nextWaddr + 1;
	 end
      end
   end
   
   reg [ADDR_WIDTH-1:0] waddr_ss;
    
   assign raddr_pre  = (re) ? nextRaddr : raddr;
   assign empty      = (raddr == waddr_ss);
   assign rUsedSpace = waddr_ss - raddr;
   
   always @(posedge rclk) begin
      waddr_ss  <= waddr;
   end

   always @(posedge rclk or posedge reset) begin
      if(reset) begin
	 raddr <= 0;
      end else begin
	 raddr <= raddr_pre;
	 if(re) begin
`ifdef SIM
	    if(empty) $display("%m(%t) Reading from fifo when empty",$time);
`endif	    
	 end
      end
   end

   rate_changerDualPortRAM #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
      RAM(
	  .clka(wclk),
	  .clkb(rclk),
	  .wea(we),
	  .addra(waddr),
	  .addrb(raddr_pre),
	  .dia(wdata),
	  .doa(),
	  .dob(rdata)
	  );
   
endmodule

    
///////////////////////////////////////////////////////////////////////////////
// Dual-Port Block RAM with Different Clocks (from XST User Manual)
module rate_changerDualPortRAM
   #(parameter ADDR_WIDTH = 4, DATA_WIDTH=8)
   (
    input  clka,
    input  clkb,
    input  wea,
    input  [ADDR_WIDTH-1:0] addra,
    input  [ADDR_WIDTH-1:0] addrb,
    input  [DATA_WIDTH-1:0] dia,
    output [DATA_WIDTH-1:0] doa,
    output [DATA_WIDTH-1:0] dob
    );

   reg [DATA_WIDTH-1:0]     RAM [(1<<ADDR_WIDTH)-1:0];
   reg [ADDR_WIDTH-1:0]     read_addra;
   reg [ADDR_WIDTH-1:0]     read_addrb;
   always @(posedge clka) begin
      if (wea == 1'b1) RAM[addra] <= dia;
      read_addra <= addra;
   end
   always @(posedge clkb) begin
      read_addrb <= addrb;
   end
   assign doa = RAM[read_addra];
   assign dob = RAM[read_addrb];
endmodule
