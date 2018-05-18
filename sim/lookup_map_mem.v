module lookup_map_mem
   (input clka,
    input        wea,
    input [9:0]  addra,
    input [9:0]  dina,
    output [9:0] douta,
    input        ena,
    input        enb,
    
    input        clkb,
    input        web,
    input [9:0]  addrb,
    input [9:0]  dinb,
    output [9:0] doutb);

   reg [9:0]     data[0:1023];
   reg [9:0]     addra_s, addrb_s;
   
   always @(posedge clka) begin
      addra_s <= addra;
      douta <= data[addra_s];
      if(wea) begin
         data[addra] <= dina;
      end
   end
   always @(posedge clkb) begin
      addrb_s <= addrb;
      doutb <= data[addrb_s];
      if(web) begin
         data[addrb] <= dinb;
      end
   end

   
endmodule
