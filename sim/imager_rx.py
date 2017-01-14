from basetest import simtest
import testutil
import logging
import numpy

###############################################################################
class ImagerRxTest(simtest):

    def testImagerRx(self):
        """Capture RAW images and see that it matches expectation"""

        num_cols = 1280
        num_rows = 100

        self.dev.set("Imager", "mode", 5)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "RAW")
        self.dev.set("Imager", "enable", 1)
        x = numpy.zeros([num_rows, num_cols], dtype=numpy.uint16)
        self.dev.read("STREAM", 0, x)

        # calculate what x should be
        y = (numpy.arange(0,num_cols).repeat(num_rows).reshape(num_cols,num_rows).transpose() + numpy.arange(0,num_rows).repeat(num_cols).reshape(num_rows,num_cols) + x[0,0]) & 0x3FF

        self.assertTrue((x==y).all(), "1st captured image does not match calculated image")

        for i in range(4): # capture some more images
            self.dev.read("STREAM", 0, x)
            y = (y + 1) & 0x3FF
            self.assertTrue((x==y).all(), str(i+2) + " captured image does not match calculated image")
        
