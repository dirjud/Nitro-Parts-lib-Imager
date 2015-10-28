// Description: deserializes Omnivision's custom SPI. Outputs a standard FV,LV,DAT interface

module omnivision_spi_rx
  #(parameter DATA_WIDTH=8,
    parameter SPI_WIDTH=2,
    parameter DIM_WIDTH=12
    )
  (
   input 		   resetb,
   input 		   sclk,
   input [SPI_WIDTH-1:0]   sdat,
   output [DATA_WIDTH-1:0] dat,
   output reg [DIM_WIDTH-1:0]  num_rows,
   output reg [DIM_WIDTH-1:0]  num_cols,
   output reg		   lv,
   output reg		   fv
   );

   wire [7:0] MODE = 8'h2A; // RAW8 mode
   wire [31:0] header = { MODE, 8'h00, 8'hFF, 8'hFF };
   reg [31:0]  sr;
   reg [5:0]  pos;
   wire [5:0]  next_pos = pos + 2;
   reg [1:0]   state;
   

   
   always @(posedge sclk or negedge resetb) begin
      if(!resetb) begin
	 sr <= 0;
	 fv <= 0;
	 lv <= 0;
	 pos <= 0;
	 state <= 0;
	 num_cols <= 0;
	 num_rows <= 0;
      end else begin
	 sr <= { sdat, sr[31:2] };
	 if(sr == header) begin
	    pos <= 0;
	    fv  <= 0;
	    state <= 1;
	 end else begin
	    if(state == 1) begin
	       fv <= 1;
	       if(next_pos == 32) begin
		  state <= 2;
		  pos <= 0;
		  num_cols <= sr[DIM_WIDTH-1:0];
		  num_rows <= sr[DIM_WIDTH+15:16];
	       end else begin
		  pos <= next_pos;
	       end

	    end
	    
	 end

	 
      end
   end
endmodule
