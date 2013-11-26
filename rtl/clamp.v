module clamp
  #(DATAI_WIDTH=13,
    DATAO_WIDTH=8,
    SIGNED=1)
   (
    input [DATAI_WIDTH-1:0]  xi,
    output [DATAO_WIDTH-1:0] xo
    );


   wire over_max_signed = (xi[DATAI_WIDTH-1] == 0) && (|xi[DATAI_WIDTH-2:DATAO_WIDTH]);
   wire over_max_unsigned = |xi[DATAI_WIDTH-1:DATAO_WIDTH];

   wire under_min_signed = (xi[DATAI_WIDTH-1] == 1) && !(&xi[DATAI_WIDTH-2:DATAO_WIDTH]);
   
   
   assign xo = (SIGNED==1 && over_max_signed ) ? { 1'b0, { DATAO_WIDTH-1 { 1'b1 }}} :
	     (SIGNED==1 && under_min_signed) ? { 1'b1, { DATAO_WIDTH-1 { 1'b0 }}} :
	     (SIGNED==0 && over_max_signed ) ? { DATAO_WIDTH { 1'b1 }} :
	xi[DATAO_WIDTH-1:0];
   

endmodule
