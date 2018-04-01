module rotate_matrix
  #(parameter IN_WIDTH=8,
    ANGLE_WIDTH=10,
    OUT_WIDTH=8
    )
   (input signed [ANGLE_WIDTH-1:0] cos_theta,
    input signed [ANGLE_WIDTH-1:0] sin_theta,
    input [IN_WIDTH-1:0]           xi,
    input [IN_WIDTH-1:0]           yi,
    input [IN_WIDTH-1:0]           num_cols,
    input [IN_WIDTH-1:0]           num_rows,
    output signed [OUT_WIDTH-1:0]  xo,
    output signed [OUT_WIDTH-1:0]  yo
   );
   
   wire [IN_WIDTH-1:0]             num_cols0 = num_cols >> 1;
   wire [IN_WIDTH-1:0]             num_rows0 = num_rows >> 1;
   
   // row/col position with respect to the center of the image
   wire signed [IN_WIDTH-1:0] xi0 = xi - num_cols0;
   wire signed [IN_WIDTH-1:0] yi0 = yi - num_rows0;
   
   // apply the matrix multiply
   wire signed [IN_WIDTH+ANGLE_WIDTH:0] xo0 = (xi0 * cos_theta) - (yi0 * sin_theta);
   wire signed [IN_WIDTH+ANGLE_WIDTH:0] yo0 = (xi0 * sin_theta) + (yi0 * cos_theta);

   // drop extra bits but keep the extra sign bit at the top
   wire signed [OUT_WIDTH-1:0] xo1 = xo0[IN_WIDTH+ANGLE_WIDTH-3:IN_WIDTH+ANGLE_WIDTH-OUT_WIDTH-2];
   wire signed [OUT_WIDTH-1:0] yo1 = yo0[IN_WIDTH+ANGLE_WIDTH-3:IN_WIDTH+ANGLE_WIDTH-OUT_WIDTH-2];

   // restore origin to upper right of image
   assign xo = xo1 + {num_cols0, {(OUT_WIDTH-IN_WIDTH){1'b0}}} ;
   assign yo = yo1 + {num_rows0, {(OUT_WIDTH-IN_WIDTH){1'b0}}};

endmodule
