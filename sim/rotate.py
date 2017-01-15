import testutil
import numpy, math
import pylab, matplotlib
tb, dev = testutil.tb_setup("rotate")


class Tmp:
    pass
self= Tmp()
self.dev = dev


num_cols = 1280
num_rows = 720
self.dev.set("Imager", "mode", 3)
self.dev.set("Imager", "num_active_cols", num_cols)
self.dev.set("Imager", "num_active_rows", num_rows)
self.dev.set("Imager", "stream_sel", "ROTATE")

y = (numpy.arange(0,num_cols).repeat(num_rows).reshape(num_cols,num_rows).transpose() + numpy.arange(0,num_rows).repeat(num_cols).reshape(num_rows,num_cols) + 50) & 0x3FF
yd = (y >> 2).astype(numpy.uint8)

for angle in numpy.linspace(0,360, 17)[:16]:
    cos_theta = math.cos(angle/180.*math.pi)
    sin_theta = math.sin(angle/180.*math.pi)
    self.dev.set("RotateTest", "cos_theta", int(round(cos_theta*256)))
    self.dev.set("RotateTest", "sin_theta", int(round(sin_theta*256)))
    
    self.dev.set("RotateTest", "enable", 1)
    self.dev.set("Imager", "enable", 1)
    x0 = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
    self.dev.read("STREAM", 0, x0)
    x1 = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
    self.dev.read("STREAM", 0, x1)
    
    x1d =(x1>> 2).astype(numpy.uint8)
    
    pylab.figure(figsize=(12,4))
    pylab.subplot(121)
    pylab.imshow(yd, matplotlib.cm.gray, interpolation='nearest')
    pylab.subplot(122)
    pylab.imshow(x1d, matplotlib.cm.gray, interpolation='nearest')

#x1 = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
#self.dev.read("STREAM", 0, x1)


