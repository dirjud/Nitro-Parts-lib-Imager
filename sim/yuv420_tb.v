`include "dtypes.v"

module yuv420_tb
  #(parameter PIXEL_WIDTH=10, MAX_COLS=1920)
   (
    input                     resetb,
    // di interface
    input                     di_clk,
    input [15:0]              di_term_addr,
    input [31:0]              di_reg_addr,
    input                     di_read_mode,
    input                     di_read_req,
    input                     di_read,
    input                     di_write_mode,
    input                     di_write,
    input [31:0]              di_reg_datai,

    output reg                di_read_rdy,
    output reg [31:0]         di_reg_datao,
    output reg                di_write_rdy,
    output reg [15:0]         di_transfer_status,
    output reg                di_en,

    input                     img_clk,
    input                     dvi,
    input [`DTYPE_WIDTH-1:0]  dtypei,
    input [15:0]              meta_datai,
    input [PIXEL_WIDTH-1:0]   yi,
    input [PIXEL_WIDTH-1:0]   ui,
    input [PIXEL_WIDTH-1:0]   vi,

    output                    dvo,
    output [`DTYPE_WIDTH-1:0] dtypeo,
    output [31:0]             datao
   );


`include "Yuv420TestTerminalInstance.v"

   always @(*) begin
      if(di_term_addr == `TERM_Yuv420Test) begin
	 di_reg_datao = Yuv420TestTerminal_reg_datao;
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


      /****************** uv offset to make it "proper" YUV *********************/
   wire                    dvo_uv_offset;
   wire [PIXEL_WIDTH-1:0]  y_uv_offset, u_uv_offset, v_uv_offset;
   wire [`DTYPE_WIDTH-1:0] dtypeo_uv_offset;
   wire [15:0] 		   meta_datao_uv_offset;
   uv_offset
    #(.PIXEL_WIDTH(PIXEL_WIDTH), .DATA_WIDTH(16))
   uv_offset
     (
      .clk(img_clk),
      .resetb(resetb),
      .enable(enable),

      .dvi(              dvi),
      .dtypei(        dtypei),
      .yi(                 yi),
      .ui(                 ui),
      .vi(                 vi),
      .meta_datai(meta_datai),

      .dvo(dvo_uv_offset),
      .dtypeo(dtypeo_uv_offset),
      .yo(y_uv_offset),
      .uo(u_uv_offset),
      .vo(v_uv_offset),
      .meta_datao(meta_datao_uv_offset)
      );

   yuv420 #(.MAX_COLS(MAX_COLS))
   yuv420
     (.clk(img_clk),
      .resetb(resetb),
      .image_type(16'b1),
      .enable(enable),
      .dvi(              dvo_uv_offset),
      .dtypei(        dtypeo_uv_offset),
      .yi(                 y_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .ui(                 u_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .vi(                 v_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .meta_datai(meta_datao_uv_offset),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao(datao)
      );
endmodule
