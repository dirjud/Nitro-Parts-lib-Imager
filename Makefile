
DI_FILE=imager_rx_terminal.py
PRJ_NAME=imager_rx
PRJ_PATH=lib/imager

include ../../lib/Makefiles/project.mk


sim_tests:
	$(MAKE) sim
	cd sim; python -m unittest ccm dot_product filter2d imager_rx interp_bilinear lookup_map rgb2yuv
