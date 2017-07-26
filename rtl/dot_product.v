`include "dtypes.v"
`include "array.v"
// Author: Lane Brooks
// Date: March 5, 2017

// Desc: Performs a dot product: a0*b0 + a1*b1 + a2*b2 + ....  You
// must specify whether the a terms are signed or not using the
// 'SIGNED_A' and 'SIGNED_B' parameter.

module dot_product
  #(parameter COEFF_WIDTH=8,
    parameter COEFF_FRAC_WIDTH=7,
    parameter DATA_WIDTH=9,
    parameter LENGTH=3,
    parameter SIGNED_COEFF=1,
    parameter SIGNED_DATA=0
    )
  (
   input [COEFF_WIDTH*LENGTH-1:0] coeff,
   input [DATA_WIDTH*LENGTH-1 :0] datai,
   output [DATA_WIDTH-1:0] datao
   );

   wire [COEFF_WIDTH-1:0]        ucoeff[0:LENGTH-1];
   wire signed [COEFF_WIDTH-1:0] scoeff[0:LENGTH-1];
   wire [DATA_WIDTH-1:0] 	 udatai[0:LENGTH-1];
   wire signed [DATA_WIDTH-1:0]  sdatai[0:LENGTH-1];
   
   `UNPACK_1DARRAY(idx0, COEFF_WIDTH, LENGTH, ucoeff, coeff)
   `UNPACK_1DARRAY(idx1, COEFF_WIDTH, LENGTH, scoeff, coeff)
   `UNPACK_1DARRAY(idx2,  DATA_WIDTH, LENGTH, udatai, datai)
   `UNPACK_1DARRAY(idx3,  DATA_WIDTH, LENGTH, sdatai, datai)
   
   localparam MULT_WIDTH = COEFF_WIDTH + DATA_WIDTH;
   wire signed [MULT_WIDTH-1:0] ssmult[0:LENGTH-1];
   wire signed [MULT_WIDTH-1:0] sumult[0:LENGTH-1];
   wire signed [MULT_WIDTH-1:0] usmult[0:LENGTH-1];
   wire [MULT_WIDTH-1:0]        uumult[0:LENGTH-1];

   function [DATA_WIDTH-1:0] abs_data;
      input [DATA_WIDTH-1:0]   data;
      begin
	 abs_data = (data[DATA_WIDTH-1]) ? (~data) + 1 : data;
      end
   endfunction
   function [COEFF_WIDTH-1:0] abs_coeff;
      input [COEFF_WIDTH-1:0]   datac;
      begin
	 abs_coeff = (datac[COEFF_WIDTH-1]) ? (~datac) + 1 : datac;
      end
   endfunction
   function [MULT_WIDTH-1:0] make_signed;
      input [MULT_WIDTH-1:0] data;
      input 		     sign;
      begin
	 make_signed = (sign == 0) ? data : ~data + 1;
      end
   endfunction

   
   // multiply
   genvar x;
   generate 
      for (x=0; x<LENGTH; x=x+1) begin 
	 assign ssmult[x] = scoeff[x] * sdatai[x];
	 assign sumult[x] = make_signed(abs_coeff(scoeff[x]) * udatai[x], scoeff[x][COEFF_WIDTH-1]);
	 assign usmult[x] = make_signed(ucoeff[x] * abs_data(sdatai[x]), sdatai[x][DATA_WIDTH-1]);
	 assign uumult[x] = ucoeff[x] * udatai[x];
      end 
   endgenerate

   // accumulate
   parameter EXTRA_ACCUM_BITS = $clog2(LENGTH);
   localparam ACCUM_WIDTH=MULT_WIDTH+EXTRA_ACCUM_BITS;
   reg signed [ACCUM_WIDTH-1:0] ssaccum;
   reg signed [ACCUM_WIDTH-1:0] suaccum;
   reg signed [ACCUM_WIDTH-1:0] usaccum;
   reg [ACCUM_WIDTH-1:0] uuaccum;
   reg [EXTRA_ACCUM_BITS-1:0] idx;
   always @(*) begin
      ssaccum = 0;
      usaccum = 0;
      suaccum = 0;
      uuaccum = 0;      
      for(idx=0; idx<LENGTH; idx=idx+1) begin
	 ssaccum = ssaccum + {{EXTRA_ACCUM_BITS{ssmult[idx][MULT_WIDTH-1]}}, ssmult[idx]};
	 usaccum = usaccum + {{EXTRA_ACCUM_BITS{usmult[idx][MULT_WIDTH-1]}}, usmult[idx]};
	 suaccum = suaccum + {{EXTRA_ACCUM_BITS{sumult[idx][MULT_WIDTH-1]}}, sumult[idx]};
	 uuaccum = uuaccum + {{EXTRA_ACCUM_BITS{1'b0}}, uumult[idx]};
      end
   end

   // clamp and drop fractional bits
   localparam BOT_POS = COEFF_FRAC_WIDTH;
   localparam TOP_POS = DATA_WIDTH + BOT_POS;
   reg [DATA_WIDTH-1:0] ssclamped;
   always @(*) begin
      if(ssaccum[ACCUM_WIDTH-1] && !(&ssaccum[ACCUM_WIDTH-2:TOP_POS-1])) begin
	 // negative overflow, so clamp
	 ssclamped = {1'b1, {DATA_WIDTH-1{1'b0}}};
      end else if(!ssaccum[ACCUM_WIDTH-1] && (|ssaccum[ACCUM_WIDTH-2:TOP_POS-1])) begin
	 ssclamped = {1'b0, {DATA_WIDTH-1{1'b1}}};
      end else begin
	 ssclamped = ssaccum[TOP_POS-1:BOT_POS];
      end
   end

   reg [DATA_WIDTH-1:0] usclamped;
   always @(*) begin
      if(usaccum[ACCUM_WIDTH-1] && !(&usaccum[ACCUM_WIDTH-2:TOP_POS-1])) begin
	 // negative overflow, so clamp
	 usclamped = {1'b1, {DATA_WIDTH-1{1'b0}}};
      end else if(!usaccum[ACCUM_WIDTH-1] && (|usaccum[ACCUM_WIDTH-2:TOP_POS-1])) begin
	 usclamped = {1'b0, {DATA_WIDTH-1{1'b1}}};
      end else begin
	 usclamped = usaccum[TOP_POS-1:BOT_POS];
      end
   end

   reg [DATA_WIDTH-1:0] suclamped;
   always @(*) begin
      if(suaccum[ACCUM_WIDTH-1]) begin
	 // output is negative, so clamp to zero
	 suclamped = 0;
      end else if(!suaccum[ACCUM_WIDTH-1] && (|suaccum[ACCUM_WIDTH-2:TOP_POS])) begin
	 // positive overflow
	 suclamped = {DATA_WIDTH{1'b1}};
      end else begin
	 suclamped = suaccum[TOP_POS-1:BOT_POS];
      end
   end

   reg [DATA_WIDTH-1:0] uuclamped;
   always @(*) begin
      if(|uuaccum[ACCUM_WIDTH-1:TOP_POS]) begin
	 // positive overflow
	 uuclamped = {DATA_WIDTH{1'b1}};
      end else begin
	 uuclamped = uuaccum[TOP_POS-1:BOT_POS];
      end
   end
   assign datao = (SIGNED_COEFF==1 && SIGNED_DATA==1) ? ssclamped :
		  (SIGNED_COEFF==0 && SIGNED_DATA==1) ? usclamped :
		  (SIGNED_COEFF==1 && SIGNED_DATA==0) ? suclamped :
		  uuclamped;
endmodule


