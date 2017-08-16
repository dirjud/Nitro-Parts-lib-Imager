`include "dtypes.v"

module circle_crop
  #(parameter PIXEL_WIDTH=10,
    parameter DIM_WIDTH=12)
  (
   input 			 clk,
   input 			 resetb,
   input 			 enable,
   input [DIM_WIDTH-1:0] 	 overage,
   input 			 dvi,
   input [PIXEL_WIDTH-1:0] 	 r,
   input [PIXEL_WIDTH-1:0] 	 g,
   input [PIXEL_WIDTH-1:0] 	 b,
   input [`DTYPE_WIDTH-1:0] 	 dtypei,
   input [15:0] 		 meta_datai,

   output reg 			 dvo,
   output reg [PIXEL_WIDTH-1:0]  ro,
   output reg [PIXEL_WIDTH-1:0]  go,
   output reg [PIXEL_WIDTH-1:0]  bo,
   output reg [`DTYPE_WIDTH-1:0] dtypeo,
   output reg [15:0] 		 meta_datao
   );

   reg [DIM_WIDTH-1:0] 	       row, col, num_rows, num_cols;
   wire [DIM_WIDTH-1:0]        next_row = row+1;
   reg [DIM_WIDTH-1:0] overage_s;
   always @(posedge clk) begin
      overage_s <= overage;
   end
   
   // calculate col and row with coordinate system with (0,0) in center of image
   wire signed [DIM_WIDTH-1:0] col0 = col - (num_cols/2);
   wire signed [DIM_WIDTH-1:0] row0 = next_row - (num_rows/2);

   wire [DIM_WIDTH-1:0]        abs_row0 = (row0 < 0) ? -row0 : row0;
   
   wire sqrt_busy, sqrt_done;
   wire [DIM_WIDTH*2-1:0] X;
   wire [DIM_WIDTH-1:0]   num_rows1 = num_rows+overage_s;
   wire [DIM_WIDTH*2-1:0] R2minusY2 = (num_rows1[DIM_WIDTH-1:1] * num_rows1[DIM_WIDTH-1:1]) - (abs_row0 * abs_row0);
   reg 			  sqrt_go;
   
   sqrt #(.WIDTH(DIM_WIDTH*2), .NUM_STEPS(DIM_WIDTH))
   sqrt
     (.clk(clk),
      .resetb(resetb),
      .go(sqrt_go),
      .S(R2minusY2),
      .X(X),
      .busy(sqrt_busy),
      .done(sqrt_done));
   
   reg signed [DIM_WIDTH-1:0] col_boundary;
   wire out_of_bounds = (col0 < -col_boundary) || (col0 > col_boundary);

   
   always @(posedge clk or negedge resetb) begin
      if(!resetb) begin
	 dvo <= 0;
	 ro  <= 0;
	 go  <= 0;
	 bo  <= 0;
	 dtypeo <= 0;
	 meta_datao <= 0;

	 row <= 0;
	 col <= 0;
	 num_rows <= 0;
	 num_cols <= 0;
	 sqrt_go <= 0;
	 col_boundary <= 0;

      end else begin
	 if(dvi && (dtypei == `DTYPE_ROW_START)) begin
	    sqrt_go <= 1;
	    if(row == 0) begin
	       col_boundary <= overage;
	    end else begin
	       col_boundary <= X[DIM_WIDTH-1:0];   // (num_rows/2 - abs_row0);
	    end
	 end else begin
	    sqrt_go <= 0;
	 end

	 dtypeo <= dtypei;
	 dvo <= dvi;
	 meta_datao <= meta_datai;

	 if(!enable) begin
	    ro  <= r;
	    go  <= g;
	    bo  <= b;
	    num_rows <= 0;
	    num_cols <= 0;

	 end else begin

	    if(dvi) begin
	       if(dtypei == `DTYPE_FRAME_START) begin
		  row <= 0;
		  col <= 0;
		  
	       end else if(dtypei == `DTYPE_FRAME_END) begin
		  num_rows <= row;

	       end else if(dtypei == `DTYPE_ROW_END) begin
		  num_cols <= col;
		  col <= 0;
		  row <= next_row;
	       end else if(dtypei == `DTYPE_PIXEL_MASK) begin
		  col <= col + 1;

		  if(num_rows > 0 && num_cols > 0) begin
		     ro  <= (out_of_bounds) ? 0 : r;
		     go  <= (out_of_bounds) ? 0 : g;
		     bo  <= (out_of_bounds) ? 0 : b;
		  end else begin
		     ro  <= r;
		     go  <= g;
		     bo  <= b;		     
		  end
		  
	       end
	    end
	 end
      end
   end

endmodule
