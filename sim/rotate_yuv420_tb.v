`include "dtypes.v"

module rotate_yuv420_tb
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

   wire                       shadow_sync;

`include "RotateYUV420TestTerminalInstance.v"

   
   always @(*) begin
      if(di_term_addr == `TERM_RotateYUV420Test) begin
	 di_reg_datao = RotateYUV420TestTerminal_reg_datao;
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
      .enable(enable_420),

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

   parameter ADDR_WIDTH=21;
   wire                    web0, oeb0, web1, oeb1;
   wire [ADDR_WIDTH-1:0]   addr0, addr1;
   wire [15:0]             ram_databus0, ram_databus1;
   rotate2rams_yuv420 #(.MAX_COLS(MAX_COLS), .ANGLE_WIDTH(18))
   rotate2raw_yuv420
     (.clk(img_clk),
      .resetb(resetb),
      .image_type(16'b1),
      .enable_420(enable_420),
      .enable_rotate(enable_rotate),
      .sin_theta(sin_theta),
      .cos_theta(cos_theta),
      .dvi(              dvo_uv_offset),
      .dtypei(        dtypeo_uv_offset),
      .yi(                 y_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .ui(                 u_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .vi(                 v_uv_offset[PIXEL_WIDTH-1:PIXEL_WIDTH-8]),
      .meta_datai(meta_datao_uv_offset),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .datao(datao),

      .web_clkp(img_clk),
      .web_clkn(!img_clk),
      .addr0(addr0),
      .web0(web0),
      .oeb0(oeb0),
      .ram_databus0(ram_databus0),
      .addr1(addr1),
      .web1(web1),
      .oeb1(oeb1),
      .ram_databus1(ram_databus1)
      );

// A Verilator is having problems with sram bus
   sram #(.ADDR_WIDTH(ADDR_WIDTH),
	  .DATA_WIDTH(16))
   sram[1:0]
     (.ceb(2'b0),
      .oeb( {        oeb1,         oeb0}),
      .web( {        web1,         web0}),
      .addr({       addr1,        addr0}),
      .data({ram_databus1, ram_databus0})
      );

   
endmodule
