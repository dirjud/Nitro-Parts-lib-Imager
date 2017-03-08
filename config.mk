NITRO_PARTS_DIR = ../..

# INC_PATHS specifies a space separated list of paths to the files
# that are `included in any of the verilog source files.  See also
# the SIM_LIBS variable.
INC_PATHS = rtl_auto \
        $(NITRO_PARTS_DIR)/lib/imager/rtl \
	$(NITRO_PARTS_DIR)/lib/VerilogTools/rtl \
	$(NITRO_PARTS_DIR)/lib/VerilogTools/sim \
	$(NITRO_PARTS_DIR)/lib/xilinx \

# INC_FILES specifies a list of files that are included in the verilog
# and are thus dependancies of the simulation.  It is not strictly
# necessary to list all of them here, but you can list any here
# that you want to use trigger a verilator rebuild or that need
# auto generated themselves.
INC_FILES =  \

# SIM_FILES is a list of simulation files that are common to all
# simulations.  Use the VERILATOR_FILES, IVERILOG_FILES, etc.
# variables to specify simulator specific files
SIM_FILES = sim/Imager_tb.v \
	$(NITRO_PARTS_DIR)/lib/HostInterface/models/fx3.v \
	rtl_auto/ImagerTerminal.v \
	rtl_auto/ImagerRxTerminal.v \
	rtl_auto/ImageTerminal.v \
	rtl_auto/CcmTestTerminal.v \
	rtl/stream2di.v \
	sim/ccm_tb.v \
	rtl/ccm.v \
	rtl_auto/RotateTestTerminal.v \
	sim/rotate_tb.v \
	rtl/rotate.v \
	rtl/rotate2rams.v \
	sim/sram.v \
	rtl_auto/DotProductTestTerminal.v \
	sim/dot_product_tb.v \
	rtl/dot_product.v \
	rtl_auto/Filter2dTestTerminal.v \
	sim/filter2d_tb.v \
	rtl/filter2d.v \
	rtl_auto/InterpBilinearTestTerminal.v \
	rtl/interp_bilinear.v \
	sim/interp_bilinear_tb.v \
	rtl_auto/Rgb2YuvTestTerminal.v \
	rtl/rgb2yuv.v \
	sim/rgb2yuv_tb.v \
	rtl_auto/LookupMapTestTerminal.v \
	rtl/lookup_map.v \
	sim/lookup_map_tb.v \


# VERILATOR specific options
#VERILATOR_ARGS=-Wno-UNOPTFLAT
VERILATOR_ARGS=
VERILATOR_FILES=
VERILATOR_CPP_FILE = ../sim/tb.cpp ../sim/vpycallbacks.cpp

# ISE_SIM specific options
ISE_SIM_ARGS = isim_tests -L unisims_ver -L secureip
ISE_SIM_FILES = sim/isim_tests.v

VSIM_TOP_MODULE = isim_tests
VSIM_SIM_FILES = sim/isim_tests.v

# SIM_DEFS specifies and `defines you want to set from the command
# line
SIM_DEFS= x512Mb sg25 x16 TRACE SIM IMAGER_CALLBACKS
SIM_DEFS += $(DEFS)


# SIM_LIBS specifies the directories for any verilog libraries whose
# files you want to auto include.  This should not be confused with
# the INC_PATHS variable.  SIM_LIBS paths are searched for modules
# that are not excility listed in the SIM_FILES or SYN_FILES list
# whereas INC_PATHS are searched for files that are `included in the
# verilog itself.
SIM_LIBS=unisims_ver secureip 

# SYN_FILES lists the files that will be synthesized
SYN_FILES = $(NITRO_PARTS_DIR)/lib/HostInterface/rtl/Fx3HostInterface.v \
	$(NITRO_PARTS_DIR)/lib/i2c/rtl/di_i2c_master.v \
	$(NITRO_PARTS_DIR)/lib/i2c/rtl/i2c_master.v \

# CUSTOM targets should go here

# DI_FILE is used by the di.mk file
DI_FILE = terminals.py

# include di.mk to auto build the di files
include ../../../lib/Makefiles/di.mk

SIM_TOP_MODULE=Imager_tb
VERILATOR_ARGS = --top-module Imager_tb
