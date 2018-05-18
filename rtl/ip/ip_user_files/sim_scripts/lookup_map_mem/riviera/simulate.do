onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+lookup_map_mem -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.lookup_map_mem xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {lookup_map_mem.udo}

run -all

endsim

quit -force
