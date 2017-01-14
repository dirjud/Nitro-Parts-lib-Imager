import testutil
import numpy, math

tb, dev = testutil.tb_setup("rotate")


class Tmp:
    pass
self= Tmp()
self.dev = dev


num_cols = 1280
num_rows = 720
self.dev.set("Imager", "mode", 5)
self.dev.set("Imager", "num_active_cols", num_cols)
self.dev.set("Imager", "num_active_rows", num_rows)
self.dev.set("Imager", "stream_sel", "ROTATE")

angle = 90
cos_theta = math.cos(angle/180.*math.pi)
sin_theta = math.sin(angle/180.*math.pi)
self.dev.set("RotateTest", "cos_theta", int(round(cos_theta*256)))
self.dev.set("RotateTest", "sin_theta", int(round(sin_theta*256)))

self.dev.set("RotateTest", "enable", 1)
self.dev.set("Imager", "enable", 1)
x0 = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
self.dev.read("STREAM", 0, x0)

y = (numpy.arange(0,num_cols).repeat(num_rows).reshape(num_cols,num_rows).transpose() + numpy.arange(0,num_rows).repeat(num_cols).reshape(num_rows,num_cols) + x0[0,0]) & 0x3FF


#x1 = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
#self.dev.read("STREAM", 0, x1)


