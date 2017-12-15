import basetest
import testutil
import logging
import numpy, math, scipy.signal
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from PIL import Image
from videoviewer import imageprocess as ip

###############################################################################
class InterpTest(basetest.simtest):

    def testInterpBilinear(self):
        """Interpolates noise with all 4 phases and checks for correctness"""
        num_cols = 200
        num_rows = 20
        self.dev.set("Imager", "mode", 0)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 30) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "INTERP")
        self.dev.set("Imager", "capture", dict(modei=0, modeo=1))
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Imager", "enable", 1)

        for phase in range(4):
            self.dev.set("InterpTest", "phase", phase)
            x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-2, num_cols-2, deptho=3)
            z = numpy.zeros([x.shape[0], x.shape[1], 3], dtype=numpy.uint16)
            ip.BayerInterp(x.reshape((20,200,1)), z, (~phase) & 0x3)

            m = abs(z[2:-2,2:-2].astype(numpy.int16) - y[1:-1,1:-1]).max()
            self.assertTrue(m<2, str(phase) + " failed")

            if False:
                pylab.figure()
                ax = pylab.subplot(311)
                basetest.raw_plot_img(x, 10)
                pylab.subplot(312, sharex=ax, sharey=ax)
                basetest.rgb_plot_img(y, 10)
                pylab.subplot(313, sharex=ax, sharey=ax)
                basetest.rgb_plot_img(z[1:-1,1:-1], 10)
                pylab.show()

    def testInterpEd(self):
        """Interpolates noise with all 4 phases and checks for correctness"""
        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 30) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "INTERP")
        self.dev.set("Imager", "capture", dict(modei=0, modeo=1))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_ed", 1)
        self.dev.set("Imager", "enable", 1)

        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-2, num_cols-2, deptho=3)
        z = numpy.zeros([x.shape[0], x.shape[1], 3], dtype=numpy.uint16)
        ip.BayerInterp(x.reshape((num_rows,num_cols,1)), z, 0)#(~phase) & 0x3)

        if True:
            pylab.figure(figsize=(18,6))
            ax = pylab.subplot(131)
            basetest.raw_plot_img(x[1:-1,1:-1], 10)
            pylab.title("Raw Bayer Data")
            pylab.subplot(132, sharex=ax, sharey=ax)
            basetest.rgb_plot_img(y, 10)
            pylab.title("Verilog Ed Interp")
            pylab.subplot(133, sharex=ax, sharey=ax)
            basetest.rgb_plot_img(z[1:-1,1:-1], 10)
            pylab.title("Python Bayer Interp")
            pylab.show()
                
