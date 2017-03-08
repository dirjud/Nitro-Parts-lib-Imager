// Author: Lane Brooks
// Date:   Jan 11, 2017
// Desc: Simulation model that buffers double imagers into ram and returns them
// over the di bus whenever read is called.
`include "dtypes.v"
`include "terminals_defs.v"

module stream2di
  #(parameter ADDR_WIDTH=22,
    parameter DI_DATA_WIDTH=32,
    parameter STREAM_DATA_WIDTH=16
    )
  (
   input 			 enable, // syncronous to rclk
   input 			 resetb,
   
   input 			 clki,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [15:0] 		 datai0,
   input [15:0] 		 datai1,
   input [15:0] 		 datai2,
   input [STREAM_DATA_WIDTH-1:0] meta_datai,
   input 			 mode, // 0 just datai0, 1 - datai0/datai1,datai2
   input 			 rclk,
   input 			 di_read_mode,
   input 			 di_read,
   output reg 			 di_read_rdy,
   output [DI_DATA_WIDTH-1:0] 	 di_reg_datao
   );

   reg [31:0] 			  buffer[0:(1<<ADDR_WIDTH)-1][0:1];

   reg [ADDR_WIDTH-1:0] 	  waddr, raddr;
   reg 				  wbuf, rbuf;
   reg 				  phase;
   reg [15:0] 			  datai_s;

   reg [1:0] 			  wstate, rstate;
   parameter WIDLE=0, WCAPTURE=1;
   parameter RWAIT_FOR_BUFFER=0, READING=1;
   
   // Write Controller
   always @(posedge clki or negedge resetb) begin
      if(!resetb || !enable) begin
	 wstate <= WIDLE;
	 phase  <= 0;
	 wbuf   <= 0;
	 waddr  <= 0;
	 
      end else begin
	 if(wstate == WIDLE) begin
	    phase  <= 0;
	    waddr <= 0;
	    
	    if(dvi && dtypei == `DTYPE_FRAME_START) begin
	       wstate <= WCAPTURE;
	    end
	    
	 end else if(wstate == WCAPTURE) begin

	    if(dvi && |(dtypei & `DTYPE_PIXEL_MASK)) begin
	       if(mode==0) begin
		  phase <= !phase;
		  if(phase == 0) begin
		     /* verilator lint_off WIDTH */
		     datai_s <= datai0;
		  end else begin
		     buffer[waddr][wbuf] <= { datai0, datai_s };
		     /* verilator lint_on WIDTH */
		     waddr <= waddr + 1;
		  end
	       end else if(mode == 1) begin
		  phase <= !phase;
		  if(phase == 0) begin
		     buffer[waddr][wbuf] = { datai1, datai0 };
		     waddr <= waddr + 1;
		     datai_s <= datai2;
		  end else begin
		     buffer[waddr][wbuf] <= { datai0, datai_s  };
		     buffer[waddr+1][wbuf] <= { datai2, datai1 };
		     waddr <= waddr + 2;
		  end
	       end

	    end else if(dvi && dtypei == `DTYPE_FRAME_END) begin
	       wstate <= WIDLE;
	       if(wbuf == rbuf) begin
		  wbuf <= !wbuf;
	       end
	    end
	 end
      end
   end

   // Read Controller
   assign di_reg_datao = buffer[raddr][rbuf];

   always @(posedge rclk or negedge resetb) begin
      if(!resetb || !enable) begin
	 raddr        <= 0;
	 rbuf         <= 0;
	 di_read_rdy  <= 0;
      end else begin

	 if(!enable) begin
	    rbuf <= 0;
	    raddr <= 0;
	    di_read_rdy <= 0;
	    
	 end else if(!di_read_mode) begin
	    di_read_rdy <= 0;
	    raddr <= 0;

	    if(rstate == READING) begin
	       rstate <= RWAIT_FOR_BUFFER;
	       rbuf <= !rbuf;
	    end
	    
	 end else begin
	    if(rstate == RWAIT_FOR_BUFFER) begin
	       if(rbuf != wbuf) begin
		  rstate <= READING;
	       end
	    end else if(rstate <= READING) begin
	       di_read_rdy <= 1;

	       if(di_read) begin
		  raddr <= raddr + 1;
	       end
	    end
	    
	 end
     
      end
   end
endmodule

