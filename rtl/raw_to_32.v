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

    input                       pack,
    output reg [31:0]             datao,
    output reg                    dvo,
    output reg [`DTYPE_WIDTH-1:0] dtypeo

    );

    reg dvo1;
    reg [31:0] lsbs;
    reg [3:0] packpos;
    reg flush_lsbs;
    reg send_row_end;

    wire [7:0] eight_bits = datai[9:2];
    wire [1:0] two_bits = datai[1:0];

    //wire [15:0] packed_datai = {{16-PIXEL_WIDTH{1'b0}}, datai[PIXEL_WIDTH-1:0]};

    always @(posedge clk or negedge resetb) begin
        if (!resetb) begin
            datao <= 0;
            dvo <= 0;
            dtypeo <= 0;
            dvo1 <= 0;
            lsbs <= 0;
            packpos <= 0;
            flush_lsbs <= 0;
            send_row_end <= 0;
        end else begin

            if (dvi) begin

                if ( (!pack && |(dtypei & `DTYPE_PIXEL_MASK)) ||
                      dtypei == `DTYPE_HEADER) begin
                    dtypeo <= dtypei;
                    if (!dvo1) begin
                        datao[15:0] <= datai;
                        dvo1 <= 1;
                        dvo <= 0;
                    end else begin
                        datao[31:16] <= datai;
                        dvo <= 1;
                        dvo1 <= 0;
                    end
                end else if (pack && |(dtypei & `DTYPE_PIXEL_MASK)) begin
                    dtypeo <= dtypei;
                    datao <= (datao << 8) | eight_bits;
                    lsbs <= (lsbs << 2) | two_bits;
                    packpos <= packpos+1;
                    dvo <= (packpos&3) == 3;
                    if (packpos==15) begin
                        flush_lsbs <= 1;
                    end
                end else begin
                    // pass through all dtypes
                    // ignores what datao is set to
                    if (dtypei == `DTYPE_ROW_END && pack) begin
                        dtypeo <= `DTYPE_PIXEL;
                        flush_lsbs <= 0;
                        packpos <= 0;
                        lsbs <= 0;
                        datao <= lsbs;
                        send_row_end <= 1;
                    end else begin
                        dtypeo <= dtypei;
                    end
                    dvo <= 1;
                end

            end else begin
                if (flush_lsbs) begin
                    datao <= lsbs;
                    lsbs <= 0;
                    flush_lsbs <= 0;
                    dvo <= 1;
                    dtypeo <= `DTYPE_PIXEL;
                end else if (send_row_end) begin
                    dvo <= 1;
                    dtypeo <= `DTYPE_ROW_END;
                    send_row_end <= 0;
                end else begin
                    dvo <= 0;
                end
            end

        end
    end


endmodule
