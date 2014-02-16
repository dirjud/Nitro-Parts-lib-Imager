`include "dtypes.v"
`include "terminals_defs.v"

module ancillary_data_sampler
  #(parameter DATA_WIDTH=16,
    parameter ANC_DATA_WIDTH=4,
    parameter LOG2_ANC_DATA_WIDTH=2
    )
  (
   input 			 resetb,

   input [ANC_DATA_WIDTH-1:0] 	 anc_datai,
   input [23:0]                  anc_clk_div,
   
   input 			 clk,
   input 			 dvi,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [DATA_WIDTH-1:0] 	 datai,

   output reg 			 dvo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [DATA_WIDTH-1:0] 	 datao
   );

   parameter PACKER_WIDTH = DATA_WIDTH + ANC_DATA_WIDTH;
   parameter LOG2_FIFO_DEPTH=4;//needs updated to match `ARRAY_SIZE_Image_anc_data
   parameter FIFO_DEPTH = (1 << LOG2_FIFO_DEPTH);
   
   reg [PACKER_WIDTH-1:0] packer;
   reg [4:0] 		  packer_pos;
   
   
   reg [DATA_WIDTH-1:0] fifo [0:FIFO_DEPTH-1];

   reg [23:0] clk_counter;
   wire       clk_overflow = clk_counter >= anc_clk_div;
   wire       dvi_header = dvi && dtypei == `DTYPE_HEADER;
   wire       fifo_read = dvi_header &&
	      (header_addr >= `Image_anc_data0) && 
	      (|read_count);
   
   reg [5:0] header_addr;
   reg [ANC_DATA_WIDTH-1:0] anc_data_s;
   wire unload_packer = packer_pos >= DATA_WIDTH;
   wire fifo_write = unload_packer && fifo_count < `ARRAY_SIZE_Image_anc_data;
   
   reg [LOG2_FIFO_DEPTH-1:0] read_count, fifo_count, read_pos, write_pos;
   
   always @(posedge clk) begin
      if(!resetb) begin
	 clk_counter <= 0;
	 anc_data_s  <= 0;
	 header_addr <= 0;
	 dvo         <= 0;
	 datao       <= 0;
	 dtypeo      <= 0;
	 packer      <= 0;
	 packer_pos  <= 0;
	 write_pos   <= 0;
	 read_pos    <= 0;
	 fifo_count  <= 0;
	 read_count  <= 0;
      end else begin
	 anc_data_s <= anc_datai;
	 
	 // maintain sampling clock counter
	 if(clk_overflow) begin
	    clk_counter <= 0;
	 end else begin
	    clk_counter <= clk_counter + 1;
	 end

	 if(clk_overflow) begin
	    packer <= { anc_datai, packer[PACKER_WIDTH-1:ANC_DATA_WIDTH] };
	    packer_pos <= packer_pos + ANC_DATA_WIDTH;
	 end else begin
	    if(unload_packer) begin
	       packer_pos <= packer_pos - DATA_WIDTH;
	    end
	 end

	 if(fifo_write && fifo_read) begin
	 end else if(fifo_write) begin
	    fifo_count <= fifo_count + 1;
	 end else if(fifo_read) begin
	    fifo_count <= fifo_count - 1;
	 end
	    
	 if(fifo_write) begin
	    /* verilator lint_off WIDTH */
	    fifo[write_pos] <= packer >> (PACKER_WIDTH - packer_pos);
	    /* verilator lint_on WIDTH */
	    write_pos   <= write_pos + 1;
	 end

	 if(fifo_read) begin
	    read_pos <= read_pos + 1;
	 end
	 
	 // maintain header address for correct image header substitution
	 if(dvi && dtypei == `DTYPE_HEADER_START) begin
	    header_addr <= 0;
	 end else if(dvi_header) begin
	    header_addr <= header_addr + 1;
	 end

	 // substitute sampled data into the image header stream
	 if(dvi_header) begin
	    if(header_addr == `Image_anc_data_count) begin
	       /* verilator lint_off WIDTH */
	       datao <= fifo_count;
	       /* verilator lint_on WIDTH */
	       read_count <= fifo_count;
	    end else if(fifo_read) begin
	       read_count <= read_count - 1;
	       datao <= fifo[read_pos];
	    end else begin
	       datao <= datai;
	    end
	 end else begin
	    datao <= datai;
	 end
	 dvo <= dvi;
	 dtypeo <= dtypei;
      end
   end

endmodule
