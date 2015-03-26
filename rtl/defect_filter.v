//  Defect filter is a simple filter attempting to correct single
//  pixels that vary widely from the surrounding pixels.  Usually this
//  is from a hot or dark pixel.
//
//  This is a horizontal only filter, comparing the center pixel with the left 
//  and right pixels for differences greater than the programmable threshold
//  levels.  If the levels are exceeded, the pixel is replaced with the
//  average of the two surrounding pixels.
//
//  Algorithm::
//
//     for each row ->
//       incoming pixel1 -> store
//       incoming pixel2 -> store
//       loop row pixels ->
//         incoming pixel3 ->
//            average = (pixel1 + pixel3)/2
//            left_delta = pixel2-pixel1
//            right_delta = pixel2-pixel3
//            if (left_delta > threshold_upper && right_delta > threshold_upper) ||
//               (left_delta > threshold_lower && right_delta > threshold_lower) ->           
//               pixel2 = average 
//
//
//         output pixel2
//         incoming pixel4 -> 
//            pixel1 = pixel2
//            pixel2 = pixel3
//            pixel3 = pixel4
//
//  Note the first and last columns of each row are not corrected.
//
//  Standard Inputs:
//      Interface conforms to dvi/dvo input/output.  See imager module.
//
//  Threshold limits:
//     threshold_upper.  If the center pixel is brighter (bigger value) than
//          the left/right pixels then this value is used to determine if the
//          pixel should be averaged.
//     threshold_lower.  If the center pixel is darker (lower value) than the
//          left/right pixels, then this value is used.
//
//  Filter Count output:
//      The output reg filter_count is the number of filtered pixels for each
//      frame.  It stays the same until the end of the frame, at which
//      time it is updated with the number of pixels that were corrected for
//      that frame.  The filter count is updated even if the enable input is
//      not asserted. 

`include "dtypes.v"

module defect_filter
 #(
     parameter DATA_WIDTH=16
  )
(
    input clk,
    input resetb,
    input en,
    input test_en,
    input [DATA_WIDTH-1:0]             test_data,

    input                              dvi,
    input [DATA_WIDTH-1:0]             datai,
    input [`DTYPE_WIDTH-1:0]           dtypei,

    input signed [DATA_WIDTH-1:0]             threshold_upper,
    input signed [DATA_WIDTH-1:0]             threshold_lower,

    output reg                         dvo,
    output reg [DATA_WIDTH-1:0]        datao,
    output reg [`DTYPE_WIDTH-1:0]      dtypeo,
    output reg [15:0]                  filter_count
);

    reg [DATA_WIDTH-1:0] datai_s, datai_ss, datao1;


    wire [DATA_WIDTH:0] outer_sum = datai + datai_ss;
    wire [DATA_WIDTH-1:0] outer_ave = outer_sum[DATA_WIDTH:1];
    wire signed [DATA_WIDTH-1:0] diff1 = datai_s - datai; // if pos then right pixel < middle 
    wire signed [DATA_WIDTH-1:0] diff2 = datai_s - datai_ss; // if pos then left pixel < middle
    wire signed [DATA_WIDTH-1:0] neg_threshold_lower = (~threshold_lower) + 1;

    reg [15:0] filter_count_cur;
    wire filter_en = (diff1 > threshold_upper && diff2 > threshold_upper) ||
                     (diff1 < neg_threshold_lower && diff2 < neg_threshold_lower);

    localparam SEND_ALL=0,
               SEND_ROW=1,
               SEND_ROW_END=2;
    reg [1:0] state;
    reg [1:0] pixelbuf;

    always @(posedge clk or negedge resetb) begin
        if(!resetb) begin
            state <= SEND_ALL;
            pixelbuf <= 0;

            datai_s <= 0;
            datai_ss <= 0;
            datao <= 0;
            dtypeo <= 0;
            dvo <= 0;
            filter_count <= 0;
            filter_count_cur <= 0;
        end else begin

        if (state == SEND_ALL) begin
            if (dvi && dtypei == `DTYPE_ROW_START) begin
                dvo <= 0;
                state <= SEND_ROW;
                pixelbuf <=0;
            end else begin
                dvo <= dvi;
                dtypeo <= dtypei;
                datao <= datai;
                if (dvi && dtypei == `DTYPE_FRAME_START) begin
                    filter_count_cur <= 0;
                end else if (dvi && dtypei == `DTYPE_FRAME_END) begin
                    filter_count <= filter_count_cur;
                end
            end
        end else if (state == SEND_ROW) begin
            if (dvi && (|(dtypei&`DTYPE_PIXEL_MASK))) begin
                datai_s <= datai;
                datai_ss <= datao;
                dvo <= 1;
                if (pixelbuf == 0) begin
                    dtypeo <= `DTYPE_ROW_START;
                    pixelbuf <= pixelbuf + 1;
                end else if (pixelbuf == 1) begin
                    dtypeo <= `DTYPE_PIXEL;
                    datao <= datai_s;
                    pixelbuf <= pixelbuf + 1;
                end else begin
                    dtypeo <= `DTYPE_PIXEL;
                    datao <= en && filter_en ? outer_ave : datai_s;
                    if (filter_en) filter_count_cur <= filter_count_cur + 1;
                end
            end else if (dvi && dtypei == `DTYPE_ROW_END) begin
                state <= SEND_ROW_END;
                dvo <= 1;
                dtypeo <= `DTYPE_PIXEL;
                datao <= datai_s;
            end

        end else if (state == SEND_ROW_END) begin
            dvo <= 1;
            dtypeo <= `DTYPE_ROW_END;
            state <= SEND_ALL;
        end
        end        
    end
endmodule
