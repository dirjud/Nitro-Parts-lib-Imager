module imager
      #(parameter DATA_WIDTH=10,
	NUM_ROWS_WIDTH=12,
	NUM_COLS_WIDTH=12)
   (
    input reset_n,
    input  clk,
    input enable, // when high, this imager will run.
    input [2:0] mode, // 0: pseudo random noise (see noise_seed input)
                      // 1: horizontal gradient
                      // 2: vertical gradient
                      // 3: diagonal gradient
                      // 4: constant based on frame number
                      // 5: diagonal gradient offset based on frame number.
    
    input [NUM_ROWS_WIDTH-1:0] num_active_rows,
    input [NUM_ROWS_WIDTH-1:0] num_virtual_rows,
    input [NUM_COLS_WIDTH-1:0] num_active_cols,
    input [NUM_COLS_WIDTH-1:0] num_virtual_cols,
    input [31:0] noise_seed,// seed for the pseudo random noise. When
			    // this is non-zero, it will cause the
			    // same image to be generated over and
			    // over based on the value of this
			    // parameter. If this is 0, then each
			    // image will be different and generated
			    // from the seed left at the end of the
			    // previous frame.
    
    output reg [DATA_WIDTH-1:0] dat,
    output reg fv,
    output reg lv
    );

   reg [31:0] noise;
   reg [NUM_ROWS_WIDTH:0] row_count;
   reg [NUM_COLS_WIDTH:0] col_count;

   wire [NUM_ROWS_WIDTH:0] next_row_count = row_count + 1;
   wire [NUM_COLS_WIDTH:0] next_col_count = col_count + 1;
   
   wire fv_wire = (row_count < {1'b0, num_active_rows});
   wire [NUM_COLS_WIDTH-1:0] hblank_fp = num_virtual_cols >> 1;
   wire 		     lv_wire = fv_wire && (col_count >= {1'b0, hblank_fp}) && (col_count < num_active_cols + hblank_fp);
   

   wire [NUM_ROWS_WIDTH:0] total_rows = num_active_rows + num_virtual_rows;
   wire [NUM_COLS_WIDTH:0] total_cols = num_active_cols + num_virtual_cols;
   reg [15:0] 		   frame_count;
   
   
   /* verilator lint_off WIDTH */
   wire [DATA_WIDTH-1:0] dat_sel = (mode == 0) ? noise[DATA_WIDTH-1:0] :
			           (mode == 1) ? row_count :
			           (mode == 2) ? col_count :
			           (mode == 3) ? row_count + col_count :
			           (mode == 4) ? frame_count :
			           frame_count + col_count + row_count;
   /* verilator lint_on WIDTH */
   
   
   always @(posedge clk or negedge reset_n) begin
      if(!reset_n) begin
         col_count <= 0;
         row_count <= 0;
         lv        <= 0;
         fv        <= 0;
         dat       <= 0;
         noise     <= 1;
	 frame_count <= 0;
      end else begin
         // generate pseudo random noise
	 if(!fv_wire) begin
	    if(|noise_seed) noise <= noise_seed;// only reseed noise at beginning of each frame if the noise seed is not 0. When noise seed is 0, let the next image be different than the previous.
	 end else begin
	    if(lv_wire) 
              noise <= { noise[30:0], !(noise[31] ^ noise[21] ^ noise[1] ^ noise[0]) };
	 end
	 
         // generate lv, fv, and dat
         if(!enable) begin
            lv             <= 0;
	    fv             <= 0;
            dat            <= 0;
            row_count      <= 0;
            col_count      <= 0;
         end else begin
	    lv  <= lv_wire;
	    fv  <= fv_wire;
	    dat <= lv_wire ? dat_sel : 0;

	    if(next_col_count >= total_cols) begin
	       col_count <= 0;
	       if(next_row_count >= total_rows) begin
		  row_count <= 0;
		  frame_count <= frame_count + 1;
	       end else begin
		  row_count <= next_row_count;
	       end
	    end else begin
	       col_count <= next_col_count;
	    end
         end
      end
   end
endmodule 
