import basetest
import testutil
import logging
import numpy, math, scipy.signal
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from PIL import Image

###############################################################################
class Filter2dTest(basetest.simtest):

    def testFilter2d(self):
        """Filters image with a series of coeffs and verifies it."""

        num_cols = 200
        num_rows = 20
        self.dev.set("Imager", "mode", 0)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 24) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "FILTER2D")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=1))
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        # test that when filter2d is not enabled that input and output match
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, depthi=3, deptho=3)
        self.assertTrue((x==y).all(), "filter2d failed to match original image when it is disabled")

        # load an identity filter and make sure input and output match
        self.dev.set("Filter2dTest", "c0", 0)
        self.dev.set("Filter2dTest", "c1", 0)
        self.dev.set("Filter2dTest", "c2", 64)
        self.dev.set("Filter2dTest", "enable", 1)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        self.assertTrue((x[2:-2,2:-2]==y).all(), "filter2d failed to match original image when an identity filter is loaded")

        # load a 2x gain filter and make sure clamping works
        self.dev.set("Filter2dTest", "c0", 0)
        self.dev.set("Filter2dTest", "c1", 0)
        self.dev.set("Filter2dTest", "c2", 127)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        yI = x[2:-2,2:-2]
        yI[:,:,0] = ((yI[:,:,0].astype(numpy.uint32)) * 127 / 64 * 127 / 64).astype(numpy.uint16)
        yI[yI>1023] = 1023
        self.assertTrue((yI==y).all(), "filter2d failed gain by 2x correctly")
        
        c = numpy.array([[ int((1./10) * 64), int((1./5) * 64), int((2./5 ) * 64), int((1./5) * 64),  int((1./10) * 64) ]]).astype(numpy.uint8)
        
        self.dev.set("Filter2dTest", "c0", c[0][0])
        self.dev.set("Filter2dTest", "c1", c[0][1])
        self.dev.set("Filter2dTest", "c2", c[0][2])
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-6, num_cols-6, depthi=3, deptho=3)
        w = scipy.signal.convolve2d(x[:,:,0],c/64., 'valid').astype(numpy.uint16)
        v = scipy.signal.convolve2d(w,c.transpose()/64., 'valid').astype(numpy.uint16)
        yI = x[2:-2,2:-2].copy()
        yI[:,:,0] = v
        self.assertTrue((y==yI).all(), "Low Pass filter failed")
        
        #pylab.figure()
        #ax = pylab.subplot(211)
        #basetest.raw_plot_img(x, 10)
        #pylab.subplot(212, sharex=ax, sharey=ax)
        #basetest.raw_plot_img(y, 10)
        #pylab.show()

    def _set_filter(self, c):
        self.dev.set("Filter2dTest", "c0", int(c[0]*64))
        self.dev.set("Filter2dTest", "c1", int(c[1]*64))
        self.dev.set("Filter2dTest", "c2", int(c[2]*64))
        c0 = numpy.array([[ int(c[0]*64)/64.,
                            int(c[1]*64)/64.,
                            int(c[2]*64)/64.,
                            int(c[1]*64)/64.,
                            int(c[0]*64)/64.]])
        return c0

    def _filter_img(self, img, c):
        w = scipy.signal.convolve2d(img.astype(numpy.uint16), c, 'valid').astype(numpy.uint16)
        v = scipy.signal.convolve2d(w,c.transpose(), 'valid').astype(numpy.uint16)
        return v

    def sharpen(self):
        
        im = Image.open("data/filter2d_image1.png")
        img = numpy.array(im)

        img2 = img.copy().astype(numpy.uint16)
        img2[:,:,0] = img[:,:,0].astype(numpy.uint16) * (128 / img[40:680,40:1240,0].mean())
        img2[:,:,1] = img[:,:,1].astype(numpy.uint16) * (128 / img[40:680,40:1240,1].mean())
        img2[:,:,2] = img[:,:,2].astype(numpy.uint16) * (128 / img[40:680,40:1240,2].mean())
        img2[img2>255] = 255
        img2_10 = img2<<2;
        num_rows, num_cols = img2_10.shape[:2]

        def callbackHandler(evt,userData):
            print "EVENT: ", evt
            if evt=="get_image":
                n=self.tb.ndarrayFromPtr(userData,4096*4096*2)
                n=n.view(numpy.uint16).reshape((4096,4096))
                n[:num_rows,:num_cols] = img2_10[:,:,1]
                return True
            return False
        self.tb.registerHandler(callbackHandler)

        self.dev.set("Imager", "mode", 6)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 504) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "FILTER2D")
        self.dev.set("Filter2dTest", "enable", 1)
        self.dev.set("Imager", "enable", 1)
        c0 = numpy.array([ 7./64, 14./64, 22./64, 14./64, 7./64 ])
        strength = 1.0
        c = self._set_filter( numpy.array([0,0,1+strength,0,0]) - c0*strength )
        print c0
        print c
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows, num_cols, num_rows-4, num_cols-4)
        im2 = Image.fromarray((x>>2).astype(numpy.uint8))
        im2.save("output/filter2d_image1.png")

        y2 = self._filter_img(x, numpy.array([c0.tolist()])).astype(numpy.int16)
        x = x[2:-2,2:-2].astype(numpy.int16)
        y3 = x + ((x-y2) * strength).astype(numpy.int16)
        y3[y3>1023] = 1023
        y3[y3<0] = 0

        import pdb
        pdb.set_trace()
        #self.assertTrue((y3==y).all(), "sharpen failed")
        
        pylab.figure()
        ax = pylab.subplot(311)
        basetest.raw_plot_img(x, 10)
        pylab.subplot(312, sharex=ax, sharey=ax)
        basetest.raw_plot_img(y3, 10)
        pylab.subplot(313, sharex=ax, sharey=ax)
        basetest.raw_plot_img(y, 10)
        pylab.show()

        
#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
