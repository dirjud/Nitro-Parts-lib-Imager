// Author: Lane Brooks
// Date:   Mar 19, 2014
// Desc: Uses three frames in the DRAM to resample the frame rate. Probably
//  does not work if num_vblank_rows or num_hblank_cols is 0. num_vblank_rows
//  and num_hblank_cols should be an even number.

`include "dtypes.v"
module framerate_change_mig
  #(parameter ADDR_WIDTH=30,
    DIM_WIDTH=12
    )
  (
   input 		       enable, // syncronous to any clock
   input [DIM_WIDTH-1:0]       num_rows, 
   input [DIM_WIDTH-1:0]       num_cols,
   input [DIM_WIDTH-1:0]       num_hblank0_cols,
   input [DIM_WIDTH-1:0]       num_hblank1_cols,
   input [DIM_WIDTH-1:0]       num_vblank0_rows,
   input [DIM_WIDTH-1:0]       num_vblank1_rows,
   input [ADDR_WIDTH-1:0]      min_addr,
   input [ADDR_WIDTH-1:0]      max_addr,
   
   input 		       wresetb,
   input 		       clki,
   input 		       dvi,
   input [`DTYPE_WIDTH-1:0]    dtypei,
   input [31:0]     datai,
   
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
   output reg 		       pW_busy,
   
   input 		       rresetb,
   input 		       rclk,
   output reg 		       dvo,
   output reg [`DTYPE_WIDTH-1:0]    dtypeo,
   output reg [31:0]                datao,
   
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
   input 		       pR_cmd_empty
   
   );

   
   parameter FIFO_WIDTH=2;
   parameter ADDR_BLOCK_WIDTH=24;
   

   reg 			       rword_sel, rfirst_word, wword_sel;
   reg [ADDR_WIDTH-1:0]  waddr_base;
   reg[5:0] rfifo_count, wfifo_count;

   reg 	    re, we;
   wire [ADDR_BLOCK_WIDTH-1:0] rdata;
   reg [ADDR_BLOCK_WIDTH-1:0] prev_rdata;
   wire 		 wfull, rempty;
   
   wire [ADDR_BLOCK_WIDTH-1:0] wdata;
   assign wdata = waddr_base[29:6];
   
   wire [FIFO_WIDTH-1:0]       wFreeSpace, rUsedSpace;
   wire 		       wwait = wFreeSpace < 2;
   
   framerateChangeFifoDualClk #(.ADDR_WIDTH(FIFO_WIDTH), 
			   .DATA_WIDTH(ADDR_BLOCK_WIDTH))
   fifoDualClk
     (.wclk(clki),
      .rclk(rclk),
      .we(we),
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
   
   reg 			       enable_r;
   reg [2:0] rstate;
   localparam RSTATE_VBLANK0 = 0,
     RSTATE_HBLANK0 = 1,
     RSTATE_SEND_ROW = 2,
     RSTATE_HBLANK1 = 3,
     RSTATE_VBLANK1 = 4;
   wire [DIM_WIDTH-1:0] total_cols = num_cols + num_hblank0_cols + num_hblank1_cols;
   reg [DIM_WIDTH-1:0] row_num, col_num;
   wire [DIM_WIDTH-1:0] next_row_num = row_num + 1;
   wire [DIM_WIDTH-1:0] next_col_num = col_num + 1;

   localparam  CMD_WRITE=0,
               CMD_READ=1,
               CMD_WRITE_WITH_AUTO_PRECHARGE=2,
               CMD_READ_WITH_AUTO_PRECHARGE=3,
               CMD_REFRESH = 4,
               CMD_IDLE = 5;

   assign pR_wr_en   = 0;
   assign pR_wr_data = 0;
   assign pW_rd_en   = 0;
   

   wire[ADDR_WIDTH-1:0] next_pR_cmd_byte_addr = pR_cmd_byte_addr + 30'd64;
   reg 			dvo0;
   reg [`DTYPE_WIDTH-1:0] dtypeo0;
   
   always @(posedge rclk or negedge rresetb) begin
      if(!rresetb) begin
	 row_num <= 0;
	 col_num <= 0;
	 rstate  <= RSTATE_VBLANK0;
	 re      <= 0;
         pR_cmd_en <= 0;
         pR_cmd_instr <= CMD_IDLE;
         pR_cmd_byte_addr <= 0;
         pR_cmd_bl   <= 0;
         rfifo_count <= 0;
	 prev_rdata  <= 0;
         pR_rd_en    <= 0;

	 dvo     <= 0;
	 datao   <= 0;
	 dtypeo  <= 0;
	 dvo0    <= 0;
	 dtypeo0 <= 0;
	 
      end else begin
	 enable_r <= enable;
	 dvo      <= dvo0;
	 dtypeo   <= dtypeo0;
	 datao    <= pR_rd_data;
	 
	 if(!enable_r) begin
	    rstate  <= RSTATE_VBLANK0;
	    row_num <= 0;
	    col_num <= 0;
	    dvo0     <= 0;

            pR_rd_en     <= 0;
            pR_cmd_en    <= 0;
            pR_cmd_instr <= CMD_IDLE;
            pR_cmd_byte_addr <= 0;
            pR_cmd_bl    <= 0;
            rfifo_count  <= 0;
	    re <= 0;
	    prev_rdata <= 0;

	 end else begin
            if(pR_cmd_instr == CMD_IDLE) begin
	       if(!pR_rd_en && pR_rd_empty) begin
		  // In this scenerio, we have drained any left over
		  // data in the read fifo and are ready to start
		  // reading a new frame
		  pR_cmd_instr <= CMD_READ;
		  if(!rempty) begin
		     re <= 1; // grab a new frame if it is available.
		     prev_rdata <= rdata;
		     pR_cmd_byte_addr <= { rdata, 6'd0 };
		     $display("Reading new frame from dram.");
		  end else begin
		     re <= 0;
		     $display("Reading old frame from dram because no new frames are available.");
		     // else use the previous frame
		     pR_cmd_byte_addr <= { prev_rdata, 6'd0 };
		  end
	       end else begin
		  re <= 0;
	       end
	    end else begin
	       re <= 0;
	       if(dvo && dtypeo == `DTYPE_FRAME_END) begin
		  pR_cmd_instr <= CMD_IDLE;
		  // at the end of the read frame, drain data left in
		  // the read fifo.
	       end

	       // figure out if we need to fetch more data from for the
	       // read fifo
	       pR_cmd_bl <= 15;
	       if(!pR_cmd_full && !pR_cmd_en && rfifo_count < 32) begin
		  pR_cmd_en <= 1;
	       end else begin
		  pR_cmd_en <= 0;
	       end
	       if(pR_cmd_en) begin
		  pR_cmd_byte_addr <= next_pR_cmd_byte_addr;
	       end
	    end
            if(pR_cmd_en && pR_rd_en) begin
               rfifo_count <= rfifo_count + 6'd15;
            end else if(pR_rd_en) begin
               rfifo_count <= rfifo_count - 6'd1;
            end else if(pR_cmd_en) begin
               rfifo_count <= rfifo_count + 6'd16;
            end
	    
	    // manage the output stream by generating VBLANK and HBLANK times
	    if (rstate == RSTATE_VBLANK0) begin
	       if(pR_cmd_instr == CMD_IDLE && !pR_rd_en && !pR_rd_empty) begin
		  // drain the data left in the read fifo.
		  pR_rd_en <= 1;
	       end else begin
		  pR_rd_en <= 0;
	       end

	       if(col_num == 0 && row_num == 0) begin
	          dtypeo0 <= `DTYPE_FRAME_START;
	          dvo0 <= 1;
	       end else if (col_num == 0) begin
                  dvo0 <= 1;
                  dtypeo0 <= `DTYPE_VROW_START;
               end else begin
	          dvo0 <= 0;
	          dtypeo0 <= 0;
	       end
	       if(next_col_num >= total_cols) begin
	          col_num <= 0;
	          if(next_row_num >= num_vblank0_rows) begin
	    	  row_num <= 0;
	    	  rstate <= RSTATE_HBLANK0;
	          end else begin
	    	  row_num <= next_row_num;
	          end
	       end else begin
	          col_num <= next_col_num;
	       end
	    end else if(rstate <= RSTATE_HBLANK0) begin
	       pR_rd_en <= 0;
	       dtypeo0 <= `DTYPE_ROW_START;
	       if(col_num == 0) begin
	          dvo0 <= 1;
	       end else begin
	          dvo0 <= 0;
	       end
	       if(next_col_num >= num_hblank0_cols) begin
	          col_num <= 0;
	          rstate <= RSTATE_SEND_ROW;
	       end else begin
	          col_num <= next_col_num;
	       end
	    end else if(rstate <= RSTATE_SEND_ROW) begin
	       pR_rd_en <= 1;
	       dvo0    <= 1;
	       dtypeo0 <= `DTYPE_PIXEL_MASK;
	       if(next_col_num >= num_cols) begin
	          col_num <= 0;
	          rstate <= RSTATE_HBLANK1;
	       end else begin
	          col_num <= next_col_num;
	       end
	    end else if(rstate <= RSTATE_HBLANK1) begin
	       pR_rd_en <= 0;
	       dtypeo0 <= `DTYPE_ROW_END;
	       if(col_num == 0) begin
	          dvo0 <= 1;
	       end else begin
	          dvo0 <= 0;
	       end
	       if(next_col_num >= num_hblank1_cols) begin
	          col_num <= 0;
	          if(next_row_num >= num_rows) begin
	    	     row_num <= 0;
	    	     rstate <= RSTATE_VBLANK1;
	          end else begin
	    	     row_num <= next_row_num;
	    	     rstate <= RSTATE_HBLANK0;
	          end
	       end else begin
	          col_num <= next_col_num;
	       end
	    end else if(rstate <= RSTATE_VBLANK1) begin
	       pR_rd_en <= 0;
	       if(col_num == 0 && row_num == 0) begin
	          // send frame end signal
	          dvo0 <= 1;
	          dtypeo0 <= `DTYPE_FRAME_END;
	       end else begin
	          dvo0 <= 0;
	          dtypeo0 <= 0;
	       end
	       
	       if(next_col_num >= total_cols) begin
	          col_num <= 0;
	          if(next_row_num >= num_vblank1_rows) begin
	    	     row_num <= 0;
	    	     rstate <= RSTATE_VBLANK0;
	          end else begin
	    	     row_num <= next_row_num;
	          end
	       end else begin
	          col_num <= next_col_num;
	       end
	    end else begin
	       pR_rd_en <= 0;
	       // shouldn't get to this state, but just in case
	       rstate <= RSTATE_VBLANK0;
	    end
	 end
      end
   end

   reg enable_w;
   wire dtype_needs_written = (|(dtypei & `DTYPE_PIXEL_MASK));

   reg [29:0] frame_length;
   wire [29:0] frame_length_rounded  = (frame_length + 63) & 30'h3FFFFFC0;
   assign pW_cmd_instr = CMD_WRITE;
   wire wfifo_empty = wfifo_count == 0;
   wire [29:0] next_waddr_base0      = waddr_base + frame_length_rounded;
   wire [29:0] next_waddr_base       = (next_waddr_base0 >= max_addr) ? min_addr : next_waddr_base0;
   wire [29:0] next_pW_cmd_byte_addr = pW_cmd_byte_addr + 30'd64;


   always @(posedge clki or negedge wresetb) begin
      if(!wresetb) begin
         pW_wr_en     <= 0;
         pW_wr_data   <= 0;
      end else begin

	 if(!enable_w) begin
            pW_wr_en     <= 0;
            pW_wr_data   <= 0;
         end else begin
            if(dvi && dtype_needs_written) begin
	       pW_wr_en <= 1;
	       pW_wr_data <= datai;
            end else begin
               pW_wr_en <= 0;
            end
         end
      end
   end

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
	 enable_w <= 0;
	 
      end else begin // if (!wresetb)
	 enable_w <= enable;

	 if(!enable_w && wfifo_empty) begin
            pW_cmd_en        <= 0;
            pW_cmd_byte_addr <= 0;
            pW_cmd_bl        <= 0;
            wfifo_count      <= 0;
	    waddr_base       <= 0;
	    we               <= 0;

	    state <= STATE_WRITE_FRAME;
	    frame_length <= 0;

	 end else begin
	    if(we) begin
	       waddr_base <= next_waddr_base;
	    end
	    
	    if(dvi && dtypei == `DTYPE_HEADER_END) begin
	       if(wwait) begin
		  $display("Dropping frame because fifo is full.");
		  we <= 0;
	       end else begin
		  $display("Committing frame to dram");
		  we <= 1;
	       end

	    end else if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       we <= 0;
	       pW_cmd_byte_addr <= waddr_base;

	    end else begin
	       we <= 0;
	       if(pW_cmd_en) begin
		  pW_cmd_byte_addr <= next_pW_cmd_byte_addr;
               end

	       if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
		  frame_length <= frame_length + 4;
	       end
	    end
	    
	    if(state == STATE_HEADER_END || !enable_w) begin
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
module framerateChangeFifoDualClk #(parameter ADDR_WIDTH=4, DATA_WIDTH=8)
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

   framerateChangeDualPortRAM #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH))
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
module framerateChangeDualPortRAM
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
