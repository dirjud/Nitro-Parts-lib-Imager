module omnivision_spi_tx 
  #(parameter DATA_WIDTH=10)
   (
    input 		   resetb,
    input 		   enable,
	    
    input 		   pixclk,
    input [DATA_WIDTH-1:0] data,
    input [15:0] 	   num_rows,
    input [15:0] 	   num_cols,
    input 		   fv,
    input 		   lv,

    output 		   sclk,
    output reg [1:0] 	   sdat
    );

   wire 		   clk_hs;

   PLL_sim2 pll_hs (.input_clk(pixclk), .output_clk(clk_hs), .pll_mult(4), .pll_div(1), .debug(1));


   reg [7:0]    sr;
   reg 			   dv;
   reg 			   fv_s;
   reg [2:0] 		   header_count;
   
   wire [7:0] 		   mode = 8'h2a; // 8bit raw
   
   always @(posedge pixclk or negedge resetb) begin
      if(!resetb) begin
	 sr <= 0;
	 dv <= 0;
	 fv_s <= 0;
	 header_count <= 0;
      end else begin
	 fv_s <= fv;
	 
	 if(enable) begin
	    if((fv && !fv_s) || (|header_count)) begin // send header
	       header_count <= header_count + 1;	       
	       case(header_count)
		  0: sr <= 8'hFF;
		  1: sr <= 8'hFF;
		  2: sr <= 8'h00;
		  3: sr <= mode;
		  4: sr <= num_cols[7:0];
		  5: sr <= num_cols[15:8];
		  6: sr <= num_rows[7:0];
		  7: sr <= num_rows[15:8];
	       endcase
	       dv <= 1;

	    end else if(fv && lv) begin // send data
	       sr <= data[DATA_WIDTH-1:DATA_WIDTH-8]; // only support 8b mode for now
	       dv <= 1;

	    end else begin
	       dv <= 0;
	    end

	 end else begin
	    dv <= 0;
	    header_count <= 0;
	 end
      end
   end

   reg [2:0] pos;
   reg [7:0] srs;
/* verilator lint_off UNOPTFLAT */
   reg 	     dvs, dvss, dvsss;
/* verilator lint_on UNOPTFLAT */
   wire [2:0] next_pos = (dvs != dv) ? 0 : pos + 2;
   
   always @(posedge clk_hs or negedge resetb) begin
      if(!resetb) begin
	 pos <= 0;
	 dvs <= 0;
	 sdat <= 0;
	 
      end else begin
	 dvs  <= dv;
	 dvss <= dvs;
	 srs  <= sr;
	 pos  <= next_pos;

	 if(dvs) begin
	    sdat[1] <= srs[pos + 1];
	    sdat[0] <= srs[pos];
	 end else begin
	    sdat <= 0;
	 end
      end
   end // always @ (posedge clk_hs or negedge resetb)

   assign sclk = (dvss == 0) ? 0 : !clk_hs;
   
endmodule
