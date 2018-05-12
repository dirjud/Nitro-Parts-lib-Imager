from basetest import simtest
import testutil
import logging
import numpy, math
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from videoviewer import imageprocess as ip

###############################################################################
class YUV420Test(simtest):

    def testYUV420(self):
        """Enables YVU420 and checks it for accuracy"""

        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("Yuv420Test", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
        self.dev.read("STREAM_INPUT", 0, y)
        yd = (y >> 2).astype(numpy.uint8)
        yd[:,:,1:] += 128
        rgb = numpy.zeros_like(yd)
        ip.YUV2RGB(yd, rgb)

        x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
        self.dev.read("STREAM_OUTPUT", 0, x)
        yuv = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint8)
        ip.Stream2YUV(x, yuv)
        xd = numpy.zeros_like(yuv)
        ip.YUV2RGB(yuv, xd)

        z_yuv = numpy.zeros_like(yd)
        z_yuv[:,:,0] = yd[:,:,0] # copy the y channel
        uv = ((yd[0::2,0::2,1:].astype(int) + yd[1::2,0::2,1:] + yd[0::2,1::2,1:] + yd[1::2,1::2,1:]) / 4).astype(numpy.uint8)
        z_yuv[0::2,0::2,1:] = uv
        z_yuv[1::2,0::2,1:] = uv
        z_yuv[0::2,1::2,1:] = uv
        z_yuv[1::2,1::2,1:] = uv
        z = numpy.zeros_like(z_yuv)
        ip.YUV2RGB(z_yuv, z)

        if False:
            pylab.figure(figsize=[10,8])
            pylab.subplots_adjust(left=0.0, right=1.0, bottom=0.04, top=1.0, wspace=0.005)
            ax = pylab.subplot(221)
            pylab.imshow(rgb, interpolation='nearest')
            pylab.title("Input Image")
            pylab.subplot(222, sharex=ax, sharey=ax)
            pylab.imshow(xd, interpolation='nearest')
            pylab.title("Verilog Output Image")
            pylab.subplot(224, sharex=ax, sharey=ax)
            pylab.imshow(z, interpolation='nearest')
            pylab.title("Python Output Image")
            pylab.subplot(223, sharex=ax, sharey=ax)
            pylab.imshow( numpy.abs(z.astype(int) - xd).astype(numpy.uint8), interpolation='nearest' )
            pylab.title("Delta Image")
            pylab.show()

        self.assertTrue((yuv == z_yuv).all())

#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
