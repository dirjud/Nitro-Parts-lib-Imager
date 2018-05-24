from basetest import simtest
import basetest
import testutil
import logging
import numpy, math
import pylab, matplotlib



###############################################################################
class CropTest(simtest):

    def testCrop(self):
        """Enables crop and checks for correctness"""

        num_cols = 300
        num_rows = 200
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "CROP")

        drop_cols = 100
        drop_rows = 50

        num_orows = num_rows - drop_rows - 2
        num_ocols = num_cols - drop_cols - 2
        self.dev.set("CropTest", "num_output_rows", num_orows)
        self.dev.set("CropTest", "num_output_cols", num_ocols)
        
        self.dev.set("CropTest", "enable", 1)
        self.dev.set("Imager", "capture", dict(modei=1, modeo=1))
        self.dev.set("InterpTest", "phase", 2)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Imager", "enable", 1)

        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_orows, num_ocols, depthi=3, deptho=3)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_orows, num_ocols, depthi=3, deptho=3)

        z = numpy.zeros_like(x)
        if False:
            pylab.figure()
            pylab.imshow(x)
            pylab.figure()
            pylab.imshow(y)
            pylab.show()

        self.assertTrue((x[drop_rows/2:-drop_rows/2,drop_cols/2:-drop_cols/2] == y).all())
        
        #import pdb
        #pdb.set_trace()
        
#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
