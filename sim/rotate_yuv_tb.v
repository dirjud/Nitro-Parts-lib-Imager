`include "dtypes.v"

module rotate_yuv_tb
  #(DATA_WIDTH=10)
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
   output                    enable,
   
   input                     img_clk,
   input                     dvi,
   input [`DTYPE_WIDTH-1:0]  dtypei,
   input [DATA_WIDTH-1:0]    yi,
   input [DATA_WIDTH-1:0]    ui,
   input [DATA_WIDTH-1:0]    vi,
   input [15:0]              meta_datai,

   output                    dvo,
   output [`DTYPE_WIDTH-1:0] dtypeo,
   output [7:0]              yo,
   output [7:0]              uo,
   output [7:0]              vo,
   output [15:0]             meta_datao
   );

`include "RotateYUVTestTerminalInstance.v"

   
   always @(*) begin
      if(di_term_addr == `TERM_RotateYUVTest) begin
	 di_reg_datao = RotateYUVTestTerminal_reg_datao;
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

   /************************************************************************/
   parameter ADDR2_WIDTH=21;
   wire [ADDR2_WIDTH-1:0] addr0, addr1;
   wire        oeb0, web0, oeb1, web1;
   wire [15:0] ram_databus0, ram_databus1;

   rotate2rams_yuv #(.ADDR_WIDTH(ADDR2_WIDTH), .PIXEL_WIDTH(DATA_WIDTH), .ANGLE_WIDTH(10))
     rotate2rams_yuv
     (.clk(di_clk),
      .resetb(resetb),
      .enable(enable),
      .dvi(dvi),
      .dtypei(dtypei),
      .yi(yi),
      .ui(ui),
      .vi(vi),
      .meta_datai(meta_datai),

      .sin_theta(sin_theta),
      .cos_theta(cos_theta),
      .dvo(dvo),
      .dtypeo(dtypeo),
      .meta_datao(meta_datao),
      .yo(yo),
      .uo(uo),
      .vo(vo),

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
   sram #(.ADDR_WIDTH(ADDR2_WIDTH),
	  .DATA_WIDTH(16))
   sram0
     (.ceb(1'b0),
      .oeb(oeb0),
      .web(web0),
      .addr(addr0),
      .data(ram_databus0)
      );
   sram #(.ADDR_WIDTH(ADDR2_WIDTH),
	  .DATA_WIDTH(16))
   sram1
     (.ceb(1'b0),
      .oeb(oeb1),
      .web(web1),
      .addr(addr1),
      .data(ram_databus1)
      );

endmodule
