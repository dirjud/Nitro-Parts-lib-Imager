module imager
      #(parameter DATA_WIDTH=10,
	NUM_ROWS_WIDTH=12,
	NUM_COLS_WIDTH=12)
   (
    input reset_n,
    input  clk,
    input enable, // when high, this imager will run.
    input [3:0] mode, // 0: pseudo random noise (see noise_seed input)
                      // 1: horizontal gradient
                      // 2: vertical gradient
                      // 3: diagonal gradient
                      // 4: constant based on frame number
                      // 5: diagonal gradient offset based on frame number.
                      // 6: image from memory. (SIM only)
                      // 7: incrementing counter +1 each pixel.
                      // 8: bayer red
                      // 9: color bars
                      //10: color checkers
    input [DATA_WIDTH-1:0]  bayer_red, // if mode==bayer, this is the value for the red pixels
    input [DATA_WIDTH-1:0]  bayer_gr,  // if mode==bayer, this is the value for the green pixel on red rows
    input [DATA_WIDTH-1:0]  bayer_blue,// if mode==bayer, this is the value for the blue pixels
    input [DATA_WIDTH-1:0]  bayer_gb,  // if mode==bayer, this is the value for the green pixel on blue rows

    input [NUM_ROWS_WIDTH-1:0] num_active_rows,
    input [NUM_ROWS_WIDTH-1:0] num_virtual_rows,
    input [NUM_COLS_WIDTH-1:0] num_active_cols,
    input [NUM_COLS_WIDTH-1:0] num_virtual_cols,
                      // THE following two inputs are for simulating
                      // varying amounts of exposure for an image
                      // sensor that has a sync signal
                      // for when the frame is valid.
                      // sync is active low and will assert
                      // low at strobe_row_start and remain low for
                      // sync_rows number of rows.
    input [NUM_ROWS_WIDTH:0] sync_row_start,
    input [NUM_ROWS_WIDTH-1:0] sync_rows,
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
    output reg lv,
    output reg sync,
    output reg img_start, // pulse at pos 0,0
    output reg row_start  // pulse at the start of every row (virtual and active)
    );

`ifdef SIM
   // synth can't make a hug image buf
   reg [DATA_WIDTH-1:0] image_buf[0:4095][0:4095] /* verilator public */;
 `endif
   reg [31:0] noise;
   reg [NUM_ROWS_WIDTH:0] row_count;
   reg [NUM_COLS_WIDTH:0] col_count;
   reg [NUM_ROWS_WIDTH-1:0] num_active_rows_s;
   reg [NUM_COLS_WIDTH-1:0] num_active_cols_s;
   
   // NOTE if vblank_fp <= 1 fv won't go back low 
   // see below.. so you have to have at least vblank_fp==2
   // in order for proper fv
   wire [NUM_ROWS_WIDTH-1:0] min_virtual_rows = num_virtual_rows < 4 ? 4 : num_virtual_rows;
   wire [NUM_ROWS_WIDTH:0] total_rows = num_active_rows_s + min_virtual_rows;
   wire [NUM_COLS_WIDTH:0] total_cols = num_active_cols_s + num_virtual_cols;
 
   wire [NUM_ROWS_WIDTH:0] next_row_count = row_count + 1;
   wire [NUM_COLS_WIDTH:0] next_col_count = col_count + 1;

   wire [NUM_ROWS_WIDTH-1:0] vblank_fp = min_virtual_rows >> 1; 
   wire fv_wire = (row_count >= vblank_fp - 1) && (row_count <= total_rows - vblank_fp);
   wire [NUM_COLS_WIDTH-1:0] hblank_fp = num_virtual_cols >> 1;
   wire lv_wire = (row_count >= {1'b0, vblank_fp}) &&
                  (row_count < num_active_rows_s+vblank_fp) &&
                  (col_count >= {1'b0, hblank_fp}) && 
                  (col_count < num_active_cols_s + hblank_fp);


   reg [DATA_WIDTH-1:0] pixel_count;

  reg [15:0] 		   frame_count;

   reg [NUM_ROWS_WIDTH-1:0] sync_row;
   wire [NUM_ROWS_WIDTH:0] sync_row_end = sync_row_start + sync_rows;

   /* verilator lint_off WIDTH */
   reg [DATA_WIDTH-1:0]    color_bars;
   wire [NUM_COLS_WIDTH-1:0]    big_col_count = (mode == 10) ? (col_count >> 4) + row_count[4] : (col_count >> 4);
   always @(col_count or row_count) begin
      if(row_count[0] == 0 && col_count[0] == 0) begin // red position
         case (big_col_count)
           4,7,8,11,12   : color_bars = { DATA_WIDTH { 1'b1 }};    // 100%
           10,13,16      : color_bars = { DATA_WIDTH-1 { 1'b1 }};  //  50%
           3,5,6,9,14,15 : color_bars = 0;                         //   0%
           default:
             color_bars = ~col_count;
         endcase
      end else if(row_count[0] == 1 && col_count[0] == 1) begin // blue position
         case (big_col_count)
           6,7,9,13,14   : color_bars = { DATA_WIDTH { 1'b1 }}; // 100%
           10,11,15      : color_bars = { DATA_WIDTH-1 { 1'b1 }};  //  50%
           3,4,5,8,12,16 : color_bars = 0;                       //   0%
           default:
             color_bars = ~col_count;
         endcase
      end else begin // green position
         case (big_col_count)
           5,8,9,15,16   : color_bars = { DATA_WIDTH { 1'b1 }}; // 100%
           10,12,14      : color_bars = { DATA_WIDTH-1 { 1'b1 }};  //  50%
           3,4,6,7,12,13 : color_bars = 0;              //   0%
           default:
             color_bars = col_count;
         endcase
      end
   end

   wire [DATA_WIDTH-1:0] bayer = (row_count & 1) == 0 ?
                                  ( (col_count & 1) == 0 ? bayer_blue : bayer_gb ) :
                                  ( (col_count & 1) == 0 ? bayer_gr : bayer_red );


   wire [DATA_WIDTH-1:0] dat_sel = (mode == 0) ? noise[DATA_WIDTH-1:0] :
			           (mode == 1) ? row_count :
			           (mode == 2) ? col_count :
			           (mode == 3) ? row_count + col_count :
			           (mode == 4) ? frame_count :
			           (mode == 5) ? frame_count + col_count + row_count :
`ifdef SIM
			           (mode == 6) ? image_buf[row_count][col_count] :
`endif
                        (mode == 7) ? pixel_count :
                         (mode == 8) ? bayer :
                         (mode == 9 || mode == 10) ? color_bars : 0;
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
         sync    <= 1;
         sync_row <= 0;
         num_active_rows_s <= 0;
         pixel_count <= 0;
         img_start <= 0;
         row_start <= 0;
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
            num_active_rows_s <= num_active_rows;
            num_active_cols_s <= num_active_cols;
            pixel_count    <= 0;
        end else begin
            if(row_count == 0 && col_count == 0) begin
                num_active_cols_s <= num_active_cols;
                num_active_rows_s <= num_active_rows;
            end
            img_start <= row_count == 0 && col_count == 0;
            row_start <= col_count == 0;
            lv  <= lv_wire;
	    fv  <= fv_wire;
	    dat <= lv_wire ? dat_sel : 0;
            pixel_count <= lv_wire ? pixel_count + 1 :
                           next_row_count >= total_rows ? 0 :
                           pixel_count;

	    if(next_col_count >= total_cols) begin
	       col_count <= 0;
	       if(next_row_count >= total_rows) begin
		  row_count <= 0;
                  sync_row <= 0;
		  frame_count <= frame_count + 1;
	       end else begin
		  row_count <= next_row_count;
                  sync_row <= sync_row+1;
                  if (next_row_count == sync_row_start) begin
                      sync <= 0;
                  end else if (next_row_count == sync_row_end) begin
                      sync <= 1;
                  end
               end
	    end else begin
	       col_count <= next_col_count;
	    end
         end
      end
   end


`ifdef IMAGER_CALLBACKS
`ifdef verilator
   always @(posedge fv) begin
      if (mode == 6) begin
         $c("get_new_image(" , image_buf, ");" );
      end
   end

   `systemc_header
   #include <vpycallbacks.h>

   `systemc_interface
    void get_new_image( SData image_buf[][4096] ) {
        VPyCallbacks::executeCallback("get_image", (void*)image_buf);
    }
    `verilog
`endif
`endif

endmodule
