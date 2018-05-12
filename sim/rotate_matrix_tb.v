`include "dtypes.v"

module rotate_matrix_tb
  (

   input             resetb,

   // di interface
   input             di_clk,
   input [15:0]      di_term_addr,
   input [31:0]      di_reg_addr,
   input             di_read_mode,
   input             di_read_req,
   input             di_read,
   input             di_write_mode,
   input             di_write,
   input [31:0]      di_reg_datai,

   output reg        di_read_rdy,
   output reg [31:0] di_reg_datao,
   output reg        di_write_rdy,
   output reg [15:0] di_transfer_status,
   output reg        di_en
   );

   wire [13:0]       xo, yo;
   wire [11:0]       xo2, yo2;
   wire [9:0]        xo3, yo3;
   
`include "RotateMatrixTestTerminalInstance.v"
   always @(*) begin
      if(di_term_addr == `TERM_RotateMatrixTest) begin
	 di_reg_datao = RotateMatrixTestTerminal_reg_datao;
 	 di_read_rdy  = 1;
	 di_write_rdy = 1;
	 di_transfer_status = 0;
	 di_en = 1;
      end else begin
         di_reg_datao = 0;
         di_read_rdy  = 1;
         di_write_rdy = 1;
         di_transfer_status = 1;
	 di_en = 0;
      end
   end
   

   rotate_matrix 
     #(
       .IN_WIDTH(12),
       .ANGLE_WIDTH(10),
       .OUT_WIDTH(14)
       )
   rotate_matrix
     (
      .cos_theta(cos_theta),
      .sin_theta(sin_theta),
      .xi(xi),
      .yi(yi),
      .num_cols(num_cols),
      .num_rows(num_rows),
      .xo(xo),
      .yo(yo)
      );


   rotate_matrix 
     #(
       .IN_WIDTH(12),
       .ANGLE_WIDTH(10),
       .OUT_WIDTH(12)
       )
   rotate_matrix2
     (
      .cos_theta(cos_theta),
      .sin_theta(sin_theta),
      .xi(xi),
      .yi(yi),
      .num_cols(num_cols),
      .num_rows(num_rows),
      .xo(xo2),
      .yo(yo2)
      );

   rotate_matrix 
     #(
       .IN_WIDTH(12),
       .ANGLE_WIDTH(10),
       .OUT_WIDTH(10)
       )
   rotate_matrix3
     (
      .cos_theta(cos_theta),
      .sin_theta(sin_theta),
      .xi(xi),
      .yi(yi),
      .num_cols(num_cols),
      .num_rows(num_rows),
      .xo(xo3),
      .yo(yo3)
      );
   
endmodule
