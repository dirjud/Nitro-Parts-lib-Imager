import basetest
import testutil
import logging
import numpy, math, scipy.signal
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from PIL import Image
from videoviewer import imageprocess as ip

###############################################################################
class InterpBilinearTest(basetest.simtest):

    def testInterp(self):
        """Filters image with a series of coeffs and verifies it."""

        num_cols = 200
        num_rows = 20
        self.dev.set("Imager", "mode", 0)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 24) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "INTERP_BILINEAR")
        self.dev.set("Imager", "capture", dict(modei=0, modeo=1))
        self.dev.set("InterpBilinearTest", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        # test that when filter2d is not enabled that input and output match
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-2, num_cols-2, deptho=3)
        z = numpy.zeros([x.shape[0], x.shape[1], 3], dtype=numpy.uint16)
        ip.BayerInterp(x.reshape((20,200,1)),z)

        pylab.figure()
        ax = pylab.subplot(311)
        basetest.raw_plot_img(x, 10)
        pylab.subplot(312, sharex=ax, sharey=ax)
        basetest.rgb_plot_img(y, 10)
        pylab.subplot(313, sharex=ax, sharey=ax)
        basetest.rgb_plot_img(z[1:-1,1:-1], 10)
        pylab.show()

        
        import pdb
        pdb.set_trace()
#        self.assertTrue((x==y).all(), "filter2d failed to match original image when it is disabled")

#        # load an identity filter and make sure input and output match
#        self.dev.set("Filter2dTest", "c0", 0)
#        self.dev.set("Filter2dTest", "c1", 0)
#        self.dev.set("Filter2dTest", "c2", 64)
#        self.dev.set("Filter2dTest", "enable", 1)
#        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-4, num_cols-4)
#        self.assertTrue((x[2:-2,2:-2]==y).all(), "filter2d failed to match original image when an identity fileter is loaded")
#
#        # load a 2x gain filter and make sure clamping works
#        self.dev.set("Filter2dTest", "c0", 0)
#        self.dev.set("Filter2dTest", "c1", 0)
#        self.dev.set("Filter2dTest", "c2", 127)
#        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-4, num_cols-4)
#        yI = (x[2:-2,2:-2].astype(numpy.uint32) * 127 / 64 * 127 / 64).astype(numpy.uint16)
#        yI[yI>1023] = 1023
#        self.assertTrue((yI==y).all(), "filter2d failed gain by 2x correctly")
#        
#        c = numpy.array([[ int((1./10) * 64), int((1./5) * 64), int((2./5 ) * 64), int((1./5) * 64),  int((1./10) * 64) ]]).astype(numpy.uint8)
#        
#        self.dev.set("Filter2dTest", "c0", c[0][0])
#        self.dev.set("Filter2dTest", "c1", c[0][1])
#        self.dev.set("Filter2dTest", "c2", c[0][2])
#        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-4, num_cols-4)
#        w = scipy.signal.convolve2d(x,c/64., 'valid').astype(numpy.uint16)
#        v = scipy.signal.convolve2d(w,c.transpose()/64., 'valid').astype(numpy.uint16)
#        x = x[2:-2,2:-2]
#        self.assertTrue((y==v).all(), "Low Pass filter failed")
#        
#        #pylab.figure()
#        #ax = pylab.subplot(211)
#        #basetest.raw_plot_img(x, 10)
#        #pylab.subplot(212, sharex=ax, sharey=ax)
#        #basetest.raw_plot_img(y, 10)
#        #pylab.show()

        
#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
