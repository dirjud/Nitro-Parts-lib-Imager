onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib rotate2rams_yuv420_fifo_opt

do {wave.do}

view wave
view structure
view signals

do {rotate2rams_yuv420_fifo.udo}

run -all

quit -force
