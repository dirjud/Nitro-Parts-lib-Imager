import basetest
import testutil
import logging
import numpy, math, scipy.signal
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from PIL import Image
from videoviewer import imageprocess as ip

###############################################################################
class Rgb2yuvTest(basetest.simtest):

    def testRgb2Yuv(self):
        """Interpolates noise with all 4 phases and checks for correctness"""
        num_cols = 200
        num_rows = 20
        self.dev.set("Imager", "mode", 0)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 30) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "RGB2YUV")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=1))
        self.dev.set("InterpBilinearTest", "enable", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-2, num_cols-2, depthi=3, deptho=3)
        z = numpy.zeros(x.shape, dtype=numpy.uint8)
        ip.RGB2YUV((x>>2).astype(numpy.uint8), z)
        z[:,:,1:] = z[:,:,1:] - 128

        ey1  = abs((y[:,:,0]>>2).astype(numpy.int16) - z[:,:,0])
        euv1 = abs(((y[:,:,1:]>>2).astype(numpy.uint8) - z[:,:,1:]).astype(numpy.int8))
        self.assertTrue(ey1.max() < 2)
        self.assertTrue(euv1.max()< 2)
