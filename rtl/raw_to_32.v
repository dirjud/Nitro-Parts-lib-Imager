// Take raw input stream (9-16 bit) and pack in 32 bit data
//

`include "dtypes.v"

module raw_to_32
    #(parameter PIXEL_WIDTH=10
     )

    (

    input clk,
    input resetb,

    input [15:0]                datai,
    input                       dvi,
    input [`DTYPE_WIDTH-1:0]    dtypei,
    //input [15:0]                meta_datai,

    output reg [31:0]             datao,
    output reg                    dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo

    );

    reg dvo1;

    //wire [15:0] packed_datai = {{16-PIXEL_WIDTH{1'b0}}, datai[PIXEL_WIDTH-1:0]};

    always @(posedge clk or negedge resetb) begin
        if (!resetb) begin
            datao <= 0;
            dvo <= 0;
            dtypeo <= 0;
            dvo1 <= 0;
        end else begin

            dtypeo <= dtypei;

            if (dvi) begin

                if (|(dtypei & `DTYPE_PIXEL_MASK) ||
                      dtypei == `DTYPE_HEADER) begin
                    if (!dvo1) begin
                        datao[15:0] <= datai;
                        dvo1 <= 1;
                        dvo <= 0;
                    end else begin
                        datao[31:16] <= datai;
                        dvo <= 1;
                        dvo1 <= 0;
                    end
                end else begin
                    dvo <= 1;
                end

            end else begin
                dvo <= 0;
            end

        end
    end


endmodule
