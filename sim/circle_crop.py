from basetest import simtest
import basetest
import testutil
import logging
import numpy, math
import pylab, matplotlib



###############################################################################
class CircleCropTest(simtest):

    def testCircleCrop(self):
        """Rotates image through series of rotations and verifies it."""

        num_cols = 300
        num_rows = 200
        self.dev.set("Imager", "mode", 2)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "CIRCLE_CROP")

        overage = 10
        self.dev.set("CircleCropTest", "overage", overage)
        
        self.dev.set("CircleCropTest", "enable", 1)
        self.dev.set("Imager", "capture", dict(modei=1, modeo=1))
        self.dev.set("InterpBilinearTest", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-2, num_cols-2, depthi=3, deptho=3)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-2, num_cols-2, depthi=3, deptho=3)

        z = numpy.zeros_like(x)
        # check each row
        num_rows, num_cols = y.shape[:2]
        R = num_rows/2
        for row in range(num_rows):
            if row == 0:
                pass
            else:
                col_boundary = int(math.sqrt((int(num_rows+overage)/2)**2 - abs(row-R)**2))
                c0 = num_cols/2 - col_boundary
                c1 = num_cols/2 + col_boundary
                z[row, c0:c1] = x[row, c0:c1]
                self.assertTrue((y[row, c0+3:c1-3] == z[row, c0+3:c1-3]).all(), str(row))
                self.assertTrue((y[row, :c0-3,:] == 0).all(), str(row))
                self.assertTrue((y[row, c1+4:,:] == 0).all(), str(row))

        if False:
            w = numpy.abs(z.astype(numpy.int16) - y)
            pylab.figure(figsize=[8,8])
            ax = pylab.subplot(221)
            basetest.rgb_plot_img(x, 10)
            pylab.title("Circle Crop Input Image")
            ax.axis('equal')
            pylab.subplot(222, sharex=ax, sharey=ax)
            basetest.rgb_plot_img(y, 10)
            pylab.title("Circle Crop Output Image")
            ax.axis('equal')
            pylab.subplot(223, sharex=ax, sharey=ax)
            basetest.rgb_plot_img(z, 10)
            pylab.title("Circle Crop Python Generated Image")
            ax.axis('equal')
            pylab.subplot(224, sharex=ax, sharey=ax)
            basetest.rgb_plot_img(w, 10)
            pylab.title("Delta Image")
            ax.axis('equal')
            pylab.show()

        
        #import pdb
        #pdb.set_trace()
        
#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
