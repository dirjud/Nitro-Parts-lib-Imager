`include "terminals_defs.v"

module raw_to_32_tb
   (
      input resetb,
      input di_clk,
      input [15:0] di_term_addr,
      input [31:0] di_reg_addr,
      input di_read_mode,
      input di_read_req,
      input di_read,
      input di_write_mode,
      input di_write,
      input [31:0] di_reg_datai,
      output di_read_rdy,
      output [31:0] di_reg_datao,
      output di_write_rdy,
      output [15:0] di_transfer_status,
      output di_en,

      input img_clk,
      input dvi,
      input [`DTYPE_WIDTH-1:0] dtypei,
      input [15:0] datai,

      output dvo,
      output [`DTYPE_WIDTH-1:0] dtypeo,
      output [31:0] datao
   );


   `include "RawTo32TestTerminalInstance.v"

   assign di_transfer_status = 0;
   assign di_reg_datao = RawTo32TestTerminal_reg_datao;
   assign di_read_rdy = 1;
   assign di_write_rdy = 1;
   assign di_en = di_term_addr == `TERM_RawTo32Test;

   // real 10 bit data from a mipi sensor has a pause every 4 clock cycles
   // when the lsbs are written to the previous 4 bytes.

   reg re;
   wire full,empty;
   wire [`DTYPE_WIDTH+15:0] fifo_datao;

   wire [`DTYPE_WIDTH-1:0] fifo_dtypeo = fifo_datao[`DTYPE_WIDTH+15:16];
   wire [11:0] usedSpace;

   fifo_singleclk
    #(.ADDR_WIDTH(12),
      .DATA_WIDTH(`DTYPE_WIDTH+16)
     )
   dvi_delay
   (
        .clk(img_clk),
        .resetb(resetb),

        .we(dvi && en),
        .re(re),
        .flush(!en),

        .full(full),
        .empty(empty),

        .wdata({dtypei,datai}),
        .rdata(fifo_datao),

        .usedSpace(usedSpace)
   );

   reg [2:0] delay;
   wire [11:0] usedSpaceNext = (re && usedSpace > 0) ? usedSpace-1 : usedSpace;
   always @(posedge img_clk or negedge resetb) begin
      if (!resetb) begin
        re <= 0;
        delay <= 0;
      end else begin
        if (usedSpace>1 || usedSpaceNext>0) begin
            if (|(fifo_dtypeo & `DTYPE_PIXEL_MASK)) begin
                if (delay+1 < 4) begin
                    re <= 1;
                    if (re) delay <= delay + 1;
                end else begin
                    re <= 0;
                    delay <= 0;
                end
            end else begin
                re <= 1;
                delay <= 0;
            end
        end else begin
            re<=0;
            delay <= 0;
        end
      end
   end


   raw_to_32
   raw_to_32
   (
    .clk (img_clk),
    .resetb (resetb),

    .datai (fifo_datao[15:0]),
    .dvi (re),
    .dtypei (fifo_dtypeo),

    .pack (pack),
    .datao (datao),
    .dvo (dvo),
    .dtypeo (dtypeo)

   );


endmodule
