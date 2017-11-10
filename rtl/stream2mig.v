// Author: Lane Brooks
// Date:   Dec 12, 2011
// Desc: DI is the rtl deivce interface part of nitro. MIG is the
//       memory interface controller to DDR2 and other memory used by
//       Xilinx. This module mates the two interfaces.
`include "dtypes.v"
`include "terminals_defs.v"

module stream2mig
  #(parameter ADDR_WIDTH=30,
    parameter DI_DATA_WIDTH=16,
    parameter STREAM_DATA_WIDTH=16
    )
  (
   input 			  enable, // syncronous to rclk

   input 			  wresetb,
   input 			  clki,
   input 			  dvi,
   input [`DTYPE_WIDTH-1:0] 	  dtypei,
   input [STREAM_DATA_WIDTH-1:0]  datai,

   input [7:0] 			  num_buffers, // should default to 2
   input 			  capture_header_only,
   
   output 			  pW_rd_en,
   input [31:0] 		  pW_rd_data,
   input 			  pW_rd_empty,
   output reg [31:0] 		  pW_wr_data,
   output reg 			  pW_wr_en,
   output reg 			  pW_cmd_en,
   output [2:0] 		  pW_cmd_instr,
   output reg [5:0] 		  pW_cmd_bl,
   output reg [ADDR_WIDTH-1:0] 	  pW_cmd_byte_addr,
   input 			  pW_cmd_full,
   input 			  pW_cmd_empty,
   output reg 			  pW_busy,
   
   input 			  rresetb,
   input 			  rclk,
   input 			  di_read_mode,
   input 			  di_read,
   output reg 			  di_read_rdy,
   output reg [DI_DATA_WIDTH-1:0] di_reg_datao,

   output reg 			  pR_rd_en,
   input [31:0] 		  pR_rd_data,
   input 			  pR_rd_empty,
   output [31:0] 		  pR_wr_data,
   output 			  pR_wr_en,
   output reg 			  pR_cmd_en,
   output reg [2:0] 		  pR_cmd_instr,
   output reg [5:0] 		  pR_cmd_bl,
   output reg [ADDR_WIDTH-1:0] 	  pR_cmd_byte_addr,
   input 			  pR_cmd_full,
   input 			  pR_cmd_empty,
`ifdef ARTIX
   output reg pR_rd_flush,
   output pR_wr_flush,
   output pW_rd_flush,
   output reg pW_wr_flush,
`endif   
   output reg 			  pR_busy
   
   );
`ifdef ARTIX
   assign pR_wr_flush = 1;
   assign pW_rd_flush = 1;
`endif   
   
   localparam FIFO_WIDTH=8;
   localparam ADDR_BLOCK_WIDTH=ADDR_WIDTH-6;
   

   reg 			       rword_sel, rfirst_word, wword_sel;
   reg [ADDR_WIDTH-1:0]  waddr_base;
   wire [ADDR_WIDTH-1:0]  next_waddr_base;
   reg[5:0] rfifo_count, wfifo_count;

   reg 	    re, we;
   reg 	    we_s, we_ss;
   wire [ADDR_BLOCK_WIDTH*2-1:0] rdata;
   wire 		 wfull, rempty;
   
   wire [ADDR_BLOCK_WIDTH*2-1:0] wdata;
   assign wdata = {waddr_base[ADDR_WIDTH-1:6], next_waddr_base[ADDR_WIDTH-1:6]};
   
   wire [FIFO_WIDTH-1:0]       wFreeSpace, rUsedSpace;
   wire 		       wwait = wFreeSpace <= (((1<<FIFO_WIDTH) - 1) - num_buffers);
   
   fifo_dualclk #(.ADDR_WIDTH(FIFO_WIDTH), 
		  .DATA_WIDTH(ADDR_BLOCK_WIDTH*2))
   fifoDualClk
     (.wclk(clki),
      .rclk(rclk),
      .we(we_ss),
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
	 pR_rd_en           = (rfirst_word || di_read || (pR_cmd_instr != CMD_READ && pR_rd_en_reg)) && !pR_rd_empty;
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
	    pR_rd_en_reg <= !pR_rd_empty && !pR_rd_en_reg; // drain any data left in the read fifo when not in read_mode
            rword_sel <= 0;
            rfirst_word  <= 1;
         end
      end
   end

   wire[ADDR_WIDTH-1:0] next_pR_cmd_byte_addr = pR_cmd_byte_addr + 64;

   wire [ADDR_BLOCK_WIDTH-1:0] next_frame_pos    = rdata[ADDR_BLOCK_WIDTH-1:0];
   wire [ADDR_BLOCK_WIDTH-1:0] cur_frame_pos     = rdata[ADDR_BLOCK_WIDTH*2-1:ADDR_BLOCK_WIDTH];
   reg 	       rwait, need_re;
   reg  [ADDR_WIDTH-3:0] read_ok_pos;
   reg  [ADDR_WIDTH-3:0] cur_read_pos; 

   always @(posedge rclk or negedge rresetb) begin
      if(!rresetb) begin
         pR_cmd_en <= 0;
         pR_cmd_instr <= CMD_IDLE;
         pR_cmd_byte_addr <= 0;
         pR_cmd_bl <= 0;
	 pR_busy <= 0;
         rfifo_count <= 0;
	 re <= 0;
         read_ok_pos <= 0;
	 rwait <= 1;
         need_re <= 0;
         cur_read_pos <= 0;
`ifdef ARTIX
	 pR_rd_flush <= 1;
`endif   
	 
      end else begin
         
	 rwait <= rempty;

	 if(!enable) begin
`ifdef ARTIX
	    pR_rd_flush <= 1;
`endif   
            pR_cmd_en    <= 0;
            pR_cmd_instr <= CMD_IDLE;
            pR_cmd_byte_addr <= 0;
            pR_cmd_bl    <= 0;
	    pR_busy      <= 0;
            rfifo_count  <= 0;
	    re <= 0;
            cur_read_pos <= 0;

         end else if(pR_cmd_instr == CMD_IDLE) begin
            need_re <= 0;
            if(di_read_mode) begin 
	       if(!rwait) begin
`ifdef ARTIX
		  pR_rd_flush <= 0;
`endif   
		  pR_cmd_byte_addr <= { cur_frame_pos, 6'b0 };
		  pR_cmd_instr <= CMD_READ;
                  re <= 1;
                  read_ok_pos <= { next_frame_pos, 4'b0 };
                  cur_read_pos <= { cur_frame_pos, 4'b0 };
	       end
	       pR_busy <= 1;
            end else begin
`ifdef ARTIX
	       pR_rd_flush <= 1;
`endif   
	       pR_busy <= 0;
	    end
            pR_cmd_en <= 0;
            rfifo_count  <= 0;
	    
         end else if(pR_cmd_instr == CMD_READ) begin
            if(!di_read_mode) begin
               pR_cmd_instr <= CMD_IDLE;
               pR_cmd_en    <= 0;
            end else begin
               if (di_read) begin
                   cur_read_pos <= cur_read_pos + 1;
               end

               if (need_re && !rwait) begin
                   re <= 1;
                   read_ok_pos <= {next_frame_pos, 4'b0};
                   need_re <= 0;
               end else begin
                   re <= 0;
                   if (di_read && cur_read_pos == read_ok_pos ) begin
                       need_re <= 1;
                   end
               end

               pR_cmd_bl <= 15;
               if(!pR_cmd_full && !pR_cmd_en && rfifo_count < 32 && (!rwait || read_ok_pos - pR_cmd_byte_addr[29:2] > 0 )) begin
                  pR_cmd_en <= 1;
               end else begin
                  pR_cmd_en <= 0;
               end
               if(pR_cmd_en) begin
                  pR_cmd_byte_addr <= next_pR_cmd_byte_addr;
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
   wire dtype_needs_written = (dtypei == `DTYPE_HEADER) || ((!capture_header_only) && (|(dtypei & `DTYPE_PIXEL_MASK)));

   reg  [ADDR_WIDTH-1:0] frame_length;
   wire [ADDR_WIDTH-1:0] frame_length_rounded  = (frame_length + 63) & 30'h3FFFFFC0;
   reg [5:0] header_addr;

   reg [2:0]   state;
   localparam STATE_WRITE_FRAME=0, STATE_WRITE_HEADER=1, STATE_HEADER_END=2, STATE_FRAME_END=3, STATE_WAIT_FRAME=4;
   /* verilator lint_off WIDTH */
   wire [STREAM_DATA_WIDTH-1:0] datai_mux = (state != STATE_WRITE_HEADER) ? datai :
	       (header_addr == `Image_frame_length_0 && STREAM_DATA_WIDTH==16) ? frame_length_rounded[15:0]  :
	       (header_addr == `Image_frame_length_1 && STREAM_DATA_WIDTH==16) ? {2'b0, frame_length_rounded[29:16] } :
	       (header_addr == `Image_frame_length_0 && STREAM_DATA_WIDTH==32) ? frame_length_rounded :
	       (header_addr == 30 && STREAM_DATA_WIDTH==32) ? waddr_base :
	       (header_addr == 28 && STREAM_DATA_WIDTH==32) ? 32'h76543210 :
	       (header_addr == 26 && STREAM_DATA_WIDTH==32) ? frame_length_rounded :
	       datai;
   /* verilator lint_on WIDTH */

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
            if(dvi && dtype_needs_written && state != STATE_WAIT_FRAME) begin
               wword_sel <= !wword_sel;
	       if(STREAM_DATA_WIDTH == 16) begin
		  header_addr <= header_addr + 1;
		  if(wword_sel) begin
                     pW_wr_data[31:16] <= datai_mux[15:0];
                     pW_wr_en <= 1;
		  end else begin
                     pW_wr_data[15:0] <= datai_mux[15:0];
                     pW_wr_en <= 0;
		  end
	       end else if(STREAM_DATA_WIDTH == 32) begin
		  header_addr <= header_addr + 2;
		  pW_wr_en <= (state == STATE_WRITE_HEADER);
		  pW_wr_data[STREAM_DATA_WIDTH-1:0] <= datai_mux;
	       end
            end else begin
               pW_wr_en <= 0;
	       if(dvi && (dtypei == `DTYPE_FRAME_END || dtypei == `DTYPE_HEADER_END)) begin
		  if(wfifo_count[1:0] != 0 && pW_wr_en == 0) begin // top off the write to a multiple of 16 bytes
		     pW_wr_data <= wfifo_count;
		     pW_wr_en <= 1;
		  end else begin
		     pW_wr_en <= 0;
		  end
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
   assign next_waddr_base            = waddr_base + frame_length_rounded;
   wire [ADDR_WIDTH-1:0] header_length         = `Image_image_data * 2;
   wire [ADDR_WIDTH-1:0] next_pW_cmd_byte_addr = pW_cmd_byte_addr + 64;

   reg [4:0]   flush_countdown;
   
   always @(posedge clki or negedge wresetb) begin
      if(!wresetb) begin
         pW_cmd_en <= 0;
         pW_cmd_byte_addr <= 0;
         pW_cmd_bl <= 0;
         wfifo_count <= 0;
	 waddr_base   <= 0;
	 we <= 0;
	 state <= STATE_WAIT_FRAME;
	 frame_length <= 0;
	 we_s <= 0;
	 we_ss<= 0;
	 pW_busy <= 0;
`ifdef ARTIX
	 pW_wr_flush <= 1;
	 flush_countdown <= 0;
`endif   
      end else begin
	 we_s <= we;
	 we_ss<= we_s;

	 if(!enable_s && wfifo_empty) begin
`ifdef ARTIX
	    pW_wr_flush <= 1;
`endif   

	    // drain any data in wfifo
            pW_cmd_en <= 0;
            pW_cmd_byte_addr <= 0;
            pW_cmd_bl <= 0;
            wfifo_count <= 0;
	    waddr_base   <= 0;
	    we <= 0;

	    state <= STATE_WAIT_FRAME;
	    frame_length <= 0;

	 end else begin

            if (state == STATE_WAIT_FRAME) begin
                // wait for a new frame before writing data. 
                if (dvi && dtypei == `DTYPE_FRAME_START) begin
                   frame_length <= header_length; 
	           pW_cmd_byte_addr <= waddr_base + header_length;
                   state <= STATE_WRITE_FRAME;
`ifdef ARTIX
		   pW_wr_flush <= 0;
`endif   
                end
            end else begin

	        if(we_ss) begin
	           waddr_base <= next_waddr_base;
	        end
	           
	        if(dvi && dtypei == `DTYPE_HEADER_END) begin
	           if(wwait) begin
	              $display("Dropping frame because fifo is full.");
	              we <= 0;
	           end else begin
	              $display("Committing frame to dram");
                      //wait_count <= 8'hff;
                      we <= 1;
	           end
		   flush_countdown <= -1;
	        end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
`ifdef ARTIX
		   pW_wr_flush <= 0;
`endif   
	           we <= 0;
	           frame_length <= header_length;
	           pW_cmd_byte_addr <= waddr_base;// + header_length;

	        end else if(dvi && dtypei == `DTYPE_HEADER_START) begin
	           we <= 0;
	           pW_cmd_byte_addr <= waddr_base; // go back to write header
	           
	        end else begin
`ifdef ARTIX
		   if(|flush_countdown) begin
		      flush_countdown <= flush_countdown - 1;
		      if(flush_countdown == 1) begin
			 //pW_wr_flush <= 1;
		      end
		   end
`endif   
	           we <= 0;
	           if(pW_cmd_en) begin
	              pW_cmd_byte_addr <= next_pW_cmd_byte_addr;
                   end

	           if(dvi && |(dtypei & `DTYPE_PIXEL_MASK) && !capture_header_only) begin
	              if(STREAM_DATA_WIDTH == 16) begin
	                 frame_length <= frame_length + 2;
	              end else begin
	                 frame_length <= frame_length + 4;
	              end
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

	        if((dvi && dtypei == `DTYPE_FRAME_END) || state == STATE_HEADER_END || state == STATE_FRAME_END || !enable_s) begin
	           // when write_mode is done, then we need to drain whatever
	           // is left over in the write fifo.
                   if(!wfifo_empty) begin
	              if(!pW_cmd_full && !pW_cmd_en && !pW_wr_en && wfifo_count[1:0] == 0) begin
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
   end
endmodule

