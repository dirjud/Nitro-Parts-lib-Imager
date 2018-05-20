// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.4 (lin64) Build 2086221 Fri Dec 15 20:54:30 MST 2017
// Date        : Sun May 20 10:05:24 2018
// Host        : borah.lane.brooks.nu running 64-bit Fedora release 27 (Twenty Seven)
// Command     : write_verilog -force -mode synth_stub
//               /home/lane/work/ubixum/prj/xenecor/src/lib/imager/rtl/ip/rotate2rams_yuv420_fifo/rotate2rams_yuv420_fifo_stub.v
// Design      : rotate2rams_yuv420_fifo
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a35tcsg324-3
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "fifo_generator_v13_2_1,Vivado 2017.4" *)
module rotate2rams_yuv420_fifo(clk, srst, din, wr_en, rd_en, dout, full, empty, 
  almost_empty)
/* synthesis syn_black_box black_box_pad_pin="clk,srst,din[37:0],wr_en,rd_en,dout[37:0],full,empty,almost_empty" */;
  input clk;
  input srst;
  input [37:0]din;
  input wr_en;
  input rd_en;
  output [37:0]dout;
  output full;
  output empty;
  output almost_empty;
endmodule
