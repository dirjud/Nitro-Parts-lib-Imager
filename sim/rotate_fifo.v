module rotate_fifo
   (input clk,
    input srst,
    input [37:0] din,
    input wr_en,
    input rd_en,
    output reg [37:0] dout,
    output reg full,
    output reg empty,
    output reg almost_empty
    );

   parameter DEPTH=1024;
   parameter DEPTH_WIDTH=$clog2(DEPTH);
   reg [37:0]  mem[0:DEPTH-1];

   
   reg [DEPTH_WIDTH-1:0] waddr, raddr;
   wire [DEPTH_WIDTH-1:0] next_waddr = waddr + 1;
   wire [DEPTH_WIDTH-1:0] next_raddr = raddr + 1;
   wire [DEPTH_WIDTH-1:0] count = waddr - raddr;
   wire [37:0]            dout_ = mem[raddr];
   always @(posedge clk) begin
      if(srst) begin
         waddr <= 0;
         raddr <= 0;
         empty <= 1;
         full <= 0;
         almost_empty <= 1;
      end else begin
         if(wr_en) begin
            mem[waddr] <= din;
            waddr <= next_waddr;
         end
         if(rd_en) begin
            dout <= dout_;
            raddr <= next_raddr;
         end
         almost_empty <= count <= 3;
         
         if(wr_en || rd_en) begin
            if(wr_en && !rd_en) begin
               empty <= 0;
               if(next_waddr == raddr) begin
                  full <= 1;
               end else begin
                  full <= 0;
               end
            end else if(rd_en && !wr_en) begin
               full <= 0;
               if(next_raddr == waddr) begin
                  empty <= 1;
               end else begin
                  empty <= 0;
               end
            end
         end
      end
   end
   
endmodule
