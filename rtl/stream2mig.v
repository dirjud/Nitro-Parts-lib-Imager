// Author: Lane Brooks
// Date:   Dec 12, 2011
// Desc: DI is the rtl deivce interface part of nitro. MIG is the
//       memory interface controller to DDR2 and other memory used by
//       Xilinx. This module mates the two interfaces.
`include "dtypes.v"
module stream2mig
  #(parameter ADDR_WIDTH=30,
    parameter DI_DATA_WIDTH=16)
  (
   input 		       enable, // syncronous to rclk

   input 		       wresetb,
   input 		       clki,
   input 		       dvi,
   input [`DTYPE_WIDTH-1:0]    dtypei,
   input [15:0] 	       datai,
   
   output 		       pW_rd_en,
   input [31:0] 	       pW_rd_data,
   input 		       pW_rd_empty,
   output reg [31:0] 	       pW_wr_data,
   output reg 		       pW_wr_en,
   output reg 		       pW_cmd_en,
   output [2:0] 	       pW_cmd_instr,
   output reg [5:0] 	       pW_cmd_bl,
   output reg [ADDR_WIDTH-1:0] pW_cmd_byte_addr,
   input 		       pW_cmd_full,
   input 		       pW_cmd_empty,
   output reg		       pW_busy,
   
   input 		       rresetb,
   input 		       rclk,
   input 		       di_read_mode,
   input 		       di_read,
   output reg 		       di_read_rdy,
   output reg [DI_DATA_WIDTH-1:0] di_reg_datao,

   output reg 		       pR_rd_en,
   input [31:0] 	       pR_rd_data,
   input 		       pR_rd_empty,
   output [31:0] 	       pR_wr_data,
   output 		       pR_wr_en,
   output reg 		       pR_cmd_en,
   output reg [2:0] 	       pR_cmd_instr,
   output reg [5:0] 	       pR_cmd_bl,
   output reg [ADDR_WIDTH-1:0] pR_cmd_byte_addr,
   input 		       pR_cmd_full,
   input 		       pR_cmd_empty,
   output reg 		       pR_busy
   
   );

   
   parameter FIFO_WIDTH=2;
   parameter ADDR_BLOCK_WIDTH=24;
   

   reg 			       rword_sel, rfirst_word, wword_sel;
   reg [ADDR_WIDTH-1:0]  waddr_base;
   reg[5:0] rfifo_count, wfifo_count;

   reg 	    re, we;
   wire [ADDR_BLOCK_WIDTH-1:0] rdata;
   wire 		 wfull, rempty;
   
   wire [ADDR_BLOCK_WIDTH-1:0] wdata;
   assign wdata = waddr_base[29:6];
   
   wire [FIFO_WIDTH-1:0]       wFreeSpace, rUsedSpace;
   wire 		       wwait = wFreeSpace < 2;
   reg 			       we_s, we_ss, we_sss;
   
   stream2migFifoDualClk #(.ADDR_WIDTH(FIFO_WIDTH), 
			   .DATA_WIDTH(ADDR_BLOCK_WIDTH))
   fifoDualClk
     (.wclk(clki),
      .rclk(rclk),
      .we(we_sss),
      .re(re),
      .resetb(wresetb),
      .flush(!enable),
      .full(wfull),
      .empty(rempty),
      .wdata(wdata),
      .rdata(rdata),
      .wFreeSpace(wFreeSpace),
      .rUsedSpace(rUsedSpace)
      );
   
      
   
   localparam  CMD_WRITE=0,
               CMD_READ=1,
               CMD_WRITE_WITH_AUTO_PRECHARGE=2,
               CMD_READ_WITH_AUTO_PRECHARGE=3,
               CMD_REFRESH = 4,
               CMD_IDLE = 5;

   assign pR_wr_en   = 0;
   assign pR_wr_data = 0;
   assign pW_rd_en   = 0;
   
   reg 			   pR_rd_en_reg, di_read_rdy_reg, pR_rd_empty_s;
   
   always @(*) begin
      if(DI_DATA_WIDTH==16) begin
	 pR_rd_en           = pR_rd_en_reg;
	 di_read_rdy        = di_read_rdy_reg;
      end else begin
	 pR_rd_en           = (rfirst_word || di_read || (!enable && pR_rd_en_reg)) && !pR_rd_empty;
	 di_read_rdy        = !pR_rd_empty && !pR_rd_empty_s;
      end
   end

   always @(posedge rclk or negedge rresetb) begin
      if(!rresetb) begin
         rword_sel    <= 0;
         rfirst_word  <= 1;
         di_reg_datao <= 0;
         di_read_rdy_reg  <= 0;
         pR_rd_en_reg     <= 0;
	 pR_rd_empty_s <= 0;
	 
      end else begin
	 pR_rd_empty_s <= pR_rd_empty;
	 di_read_rdy_reg  <= !pR_rd_empty;

	 if(!enable) begin
            rword_sel    <= 0;
            rfirst_word  <= 1;
            di_reg_datao <= 0;
            di_read_rdy_reg  <= 0;
	    pR_rd_en_reg <= !pR_rd_empty && !pR_rd_en_reg; // drain any data left in the read fifo when not in read_mode
         end else if(pR_cmd_instr == CMD_READ) begin
	    if(DI_DATA_WIDTH==16) begin
               if(di_read) rfirst_word <= 0;
               if(rfirst_word || di_read) begin
		  di_reg_datao[15:0] <= (rword_sel || !di_read) ? pR_rd_data[15:0] : pR_rd_data[31:16];
		  if(di_read) begin
                     rword_sel <= !rword_sel;
                     pR_rd_en_reg <= !rword_sel;
		  end else begin
                     pR_rd_en_reg <= 0;
		  end
               end else begin
		  pR_rd_en_reg <= 0;
               end
            end else begin // assume DI_DATA_WIDTH is 32b
	       if(pR_rd_en) begin
		  rfirst_word <= 0;
	       end else if(di_read && pR_rd_empty) begin
		  rfirst_word <= 1;
	       end
	       if(pR_rd_en) begin
		  di_reg_datao <= pR_rd_data[DI_DATA_WIDTH-1:0];
	       end
	    end
         end else begin
            rword_sel <= 0;
             if(DI_DATA_WIDTH == 16) begin
		rfirst_word <= 1;
	     end
         end
      end
   end

   wire[ADDR_WIDTH-1:0] next_pR_cmd_byte_addr = pR_cmd_byte_addr + 30'd64;

   wire [23:0] next_rpos    = next_pR_cmd_byte_addr[29:6];
   reg 	       rwait;

   reg 	read_done;
   always @(posedge rclk or negedge rresetb) begin
      if(!rresetb) begin
         pR_cmd_en <= 0;
         pR_cmd_instr <= CMD_IDLE;
         pR_cmd_byte_addr <= 0;
         pR_cmd_bl <= 0;
	 pR_busy <= 0;
         rfifo_count <= 0;
	 re <= 0;
	 read_done <= 0;
	 rwait <= 1;
	 
      end else begin
	 rwait <= rempty;
	 read_done <= next_rpos == rdata; // goes high when finished with current read buffer		  

	 if(!enable) begin
            pR_cmd_en    <= 0;
            pR_cmd_instr <= CMD_IDLE;
            pR_cmd_byte_addr <= 0;
            pR_cmd_bl    <= 0;
	    pR_busy      <= 0;
            rfifo_count  <= 0;
	    re <= 0;

         end else if(pR_cmd_instr == CMD_IDLE) begin
            if(di_read_mode) begin 
               pR_cmd_instr <= CMD_READ;
	       pR_busy <= 1;
            end else begin
	       pR_busy <= 0;
	    end
            pR_cmd_en <= 0;
	    re <= 0;
	    
         end else if(pR_cmd_instr == CMD_READ) begin
            if(!di_read_mode) begin
               pR_cmd_instr <= CMD_IDLE;
               pR_cmd_en    <= 0;
	       re <= 0;
            end else begin
               pR_cmd_bl <= 15;
               if(!pR_cmd_full && !pR_cmd_en && rfifo_count < 32 && !rwait) begin
                  pR_cmd_en <= 1;
               end else begin
                  pR_cmd_en <= 0;
               end
               if(pR_cmd_en) begin
                  pR_cmd_byte_addr <= next_pR_cmd_byte_addr;
		  re <= read_done;
               end else begin
		  re <= 0;
	       end

               if(pR_cmd_en && pR_rd_en) begin
                  rfifo_count <= rfifo_count + 6'd15;
               end else if(pR_rd_en) begin
                  rfifo_count <= rfifo_count - 6'd1;
               end else if(pR_cmd_en) begin
                  rfifo_count <= rfifo_count + 6'd16;
               end
            end
	 end
      end
   end

   reg enable_s;
   wire dtype_needs_written = (|(dtypei & `DTYPE_PIXEL_MASK)) || (dtypei == `DTYPE_HEADER);

   reg [29:0] frame_length;
   wire [29:0] frame_length_rounded  = (frame_length + 63) & 30'h3FFFFFC0;
   reg [5:0] header_addr;
   wire [15:0] datai_mux = (state != STATE_WRITE_HEADER) ? datai :
	       (header_addr == `Image_frame_length_0) ? frame_length_rounded[15:0]  :
	       (header_addr == `Image_frame_length_1) ? {2'b0, frame_length_rounded[29:16] } :

	       datai;

   always @(posedge clki or negedge wresetb) begin
      if(!wresetb) begin
         wword_sel    <= 0;
         pW_wr_en     <= 0;
         pW_wr_data   <= 0;
	 enable_s     <= 0;
	 header_addr         <= 0;
      end else begin
	 enable_s  <= enable;

	 if(!enable_s) begin
            wword_sel    <= 0;
            pW_wr_en     <= 0;
            pW_wr_data   <= 0;
         end else begin
            if(dvi && dtype_needs_written) begin
	       header_addr <= header_addr + 1;
               wword_sel <= !wword_sel;
               if(wword_sel) begin
                  pW_wr_data[31:16] <= datai_mux;
                  pW_wr_en <= 1;
               end else begin
                  pW_wr_data[15:0] <= datai_mux;
                  pW_wr_en <= 0;
               end
            end else begin
               pW_wr_en <= 0;
	       if(dvi && (dtypei == `DTYPE_FRAME_END || dtypei == `DTYPE_HEADER_END)) begin
		  wword_sel <= 0;
	       end
	       if(dvi && dtypei == `DTYPE_HEADER_START) begin
		  header_addr <= 0;
	       end
            end
         end
      end
   end

   assign pW_cmd_instr = CMD_WRITE;
   wire wfifo_empty = wfifo_count == 0;
   wire [29:0] next_waddr_base       = waddr_base + frame_length_rounded;
   wire [29:0] header_length         = `Image_image_data * 2;
   wire [29:0] next_pW_cmd_byte_addr = pW_cmd_byte_addr + 30'd64;

   reg [1:0]   state;
   parameter STATE_WRITE_FRAME=0, STATE_WRITE_HEADER=1, STATE_HEADER_END=2, STATE_FRAME_END=3;

   always @(posedge clki or negedge wresetb) begin
      if(!wresetb) begin
         pW_cmd_en <= 0;
         pW_cmd_byte_addr <= 0;
         pW_cmd_bl <= 0;
         wfifo_count <= 0;
	 waddr_base   <= 0;
	 we <= 0;
	 state <= STATE_WRITE_FRAME;
	 frame_length <= 0;
	 we_s <= 0;
	 we_ss <= 0;
	 we_sss <= 0;
      end else begin
	 we_s <= we;
	 we_ss <= we_s;
	 we_sss <= we_ss;

	 if(!enable_s && wfifo_empty) begin

	    // drain any data in wfifo
            pW_cmd_en <= 0;
            pW_cmd_byte_addr <= 0;
            pW_cmd_bl <= 0;
            wfifo_count <= 0;
	    waddr_base   <= 0;
	    we <= 0;

	    state <= STATE_WRITE_FRAME;
	    frame_length <= 0;

	 end else begin

	    if(dvi && dtypei == `DTYPE_HEADER_END) begin
	       if(wwait) begin
		  $display("Dropping frame because fifo is full.");
		  we <= 0;
	       end else begin
		  $display("Committing frame to dram");
		  we <= 1;
		  waddr_base       <= next_waddr_base;
	       end

	    end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       we <= 0;
	       frame_length <= header_length;
	       pW_cmd_byte_addr <= waddr_base + header_length;

	    end else if(dvi && dtypei == `DTYPE_HEADER_START) begin
	       we <= 0;
	       pW_cmd_byte_addr <= waddr_base; // go back to write header
	       
	    end else begin
	       we <= 0;
	       if(pW_cmd_en) begin
		  pW_cmd_byte_addr <= next_pW_cmd_byte_addr;
               end

	       if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
		  frame_length <= frame_length + 2;
	       end

	    end
	    
	    if(state == STATE_HEADER_END || !enable_s) begin
	       if(wfifo_empty) begin
		  pW_busy <= 0;
		  state <= STATE_WRITE_FRAME;
	       end
	    end else if (state == STATE_FRAME_END)begin
	       if(wfifo_empty) begin
		  pW_busy <= 0;
		  state <= STATE_WRITE_HEADER;
	       end
	    end else begin // state == STATE_WRITE
	       if(dvi && dtypei == `DTYPE_HEADER_END) begin
		  state <= STATE_HEADER_END;
	       end else if(dvi && dtypei == `DTYPE_FRAME_END) begin
		  state <= STATE_FRAME_END;
	       end else if(dvi && dtypei == `DTYPE_HEADER_START) begin
		  state <= STATE_WRITE_HEADER;
	       end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
		  state <= STATE_WRITE_FRAME;
	       end else if(dvi && dtype_needs_written) begin
		  pW_busy <= 1;
	       end
	    end

	    if(state == STATE_HEADER_END || state == STATE_FRAME_END) begin
	       // when write_mode is done, then we need to drain whatever
	       // is left over in the write fifo.
               if(!wfifo_empty) begin
		  if(!pW_cmd_full && !pW_cmd_en && !pW_wr_en) begin
                     pW_cmd_en <= 1;
                     pW_cmd_bl <= (wfifo_count - 6'd1);
		  end else begin
                     pW_cmd_en <= 0;
		  end
               end else begin
		  pW_cmd_en <= 0;
               end
	    end else begin
               pW_cmd_bl <= 15;
               if(wfifo_count >= 16 && !pW_cmd_full && !pW_cmd_en) begin
		  pW_cmd_en <= 1;
               end else begin
		  pW_cmd_en <= 0;
               end
            end
	    
            if(pW_cmd_en && pW_wr_en) begin
               wfifo_count <= (wfifo_count - pW_cmd_bl);
            end else if(pW_wr_en) begin
               wfifo_count <= wfifo_count + 6'd1;
            end else if(pW_cmd_en) begin
               wfifo_count <= (wfifo_count - pW_cmd_bl) - 6'd1;
            end
	 end
      end
   end
endmodule

///////////////////////////////////////////////////////////////////////////////
module stream2migFifoDualClk #(parameter ADDR_WIDTH=4, DATA_WIDTH=8)
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

   reg 			    wreset, rreset;
   always @(posedge wclk or negedge resetb) begin
      if(!resetb) begin
	 wreset <= 1;
      end else begin
	 wreset <= flush;
      end
   end
   always @(posedge rclk or negedge resetb) begin
      if(!resetb) begin
	 rreset <= 1;
      end else begin
	 rreset <= flush;
      end
   end

   reg [ADDR_WIDTH-1:0]    waddr, raddr, nextWaddr;
   wire [ADDR_WIDTH-1:0]   nextRaddr = raddr + 1;
   wire [ADDR_WIDTH-1:0]   raddr_pre;
   reg [ADDR_WIDTH-1:0]    raddr_ss;

   assign full       = (nextWaddr == raddr_ss);
   assign wFreeSpace = raddr_ss - nextWaddr;

   always @(posedge wclk) begin
      raddr_ss  <= raddr;
   end
      
   always @(posedge wclk or posedge wreset) begin
      if(wreset) begin
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

   always @(posedge rclk or posedge rreset) begin
      if(rreset) begin
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

   stream2migDualPortRAM #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
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
module stream2migDualPortRAM
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
