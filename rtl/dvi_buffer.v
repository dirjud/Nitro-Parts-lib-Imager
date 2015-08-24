//    FIFO_ADDR_WIDTH
//              use 0 (default) for no prebuffering of write data.
//              if addr width>0, the write data will be prebuffered
//              in order to avoid situations where write is active
//              but the dram write queue is full

`include "dtypes.v"

module dvi_buffer
# (parameter FIFO_ADDR_WIDTH=11,
   parameter DATA_WIDTH=16)

(
       input clk,
       input resetb,
       input enable, // reset queue pass through dvi when not enabled 
       input hold, // when asserted, data is buffered.

       input                    dvi,
       input [`DTYPE_WIDTH-1:0] dtypei,
       input [DATA_WIDTH-1:0]   datai,
       output full,
       output [FIFO_ADDR_WIDTH-1:0] usedSpace,

       output reg                  dvo,
       output reg [`DTYPE_WIDTH-1:0] dtypeo,
       output reg [DATA_WIDTH-1:0]   datao
       
);

//wire [FIFO_ADDR_WIDTH-1:0] usedSpace;
//wire full;
wire [`DTYPE_WIDTH-1:0] dtypeo_wire;
wire [DATA_WIDTH-1:0] datao_wire;
reg [`DTYPE_WIDTH-1:0] dtypeo_s;
reg [DATA_WIDTH-1:0] datao_s;
wire re_next = !hold && 
               (usedSpace > 1 ||
                usedSpace == 1 && !re); 
reg re;

always @(posedge clk or negedge resetb) begin
    if (!resetb) begin
        dvo <= 0;
        dtypeo <= 0;
        datao <= 0;
        re <= 0;
        datao_s <= 0;
        dtypeo_s <= 0;
    end else begin
        if (enable) begin
           re <= re_next;
           dvo <= re;
           //dtypeo_s <= dtypeo_wire;
           dtypeo <= dtypeo_wire;
           //datao_s <= datao_wire;
           datao <= datao_wire;
        end else begin
           dvo <= dvi;
           dtypeo <= dtypei;
           datao <= datai;
           re <= 0;
        end
    end
end

fifo_singleclk
 #(.ADDR_WIDTH(FIFO_ADDR_WIDTH),
   .DATA_WIDTH(`DTYPE_WIDTH+DATA_WIDTH))
fifo_singleclk
  (
    .clk(clk),
    .we(dvi),
    .re(re),
    .resetb(resetb),
    .flush(!enable),
    .full(full), 
    .empty(),
    .wdata({dtypei,datai}),
    .rdata({dtypeo_wire,datao_wire}),
    .freeSpace(),
    .usedSpace(usedSpace)
  );

endmodule
