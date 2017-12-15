from basetest import simtest
import testutil
import logging
import numpy, math
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from videoviewer import imageprocess as ip

def _rotate(img, sin_theta, cos_theta):
    img0 = numpy.zeros_like(img)
    num_rows, num_cols = img.shape
    for row in range(num_rows):
        for col in range(num_cols):
            col0 = col - num_cols/2
            row0 = row - num_rows/2

            col1 = int((col0 * cos_theta - row0 * sin_theta) * 256)
            row1 = int((col0 * sin_theta + row0 * cos_theta) * 256)

            col2 = col1 / 256
            row2 = row1 / 256

            col3 = col2 + num_cols/2
            row3 = row2 + num_rows/2
            
            #perserve the bayer phase by perserving the LSB
            col4 = (col3 & 0xFFFFFFFE) | (col & 0x00000001)
            row4 = (row3 & 0xFFFFFFFE) | (row & 0x00000001)

            ob = not(row4 >= 0 and col4 >= 0 and row4 < num_rows and col4 < num_cols)
            if not(ob):
                img0[row, col] = img[row4, col4]

            #if(col >= 565 and col < 585 and row == 0):
            #    print "col =", col, "col0=", col0,"col1=", col1,"col2=", col2,"col3=", col3,"col4=", col4,
            #    print " row=", row, "row0=", row0,"row1=", row1,"row2=", row2,"row3=", row3,"row4=", row4,
            #    print " ob=", ob, "out=", img0[row,col]

                
    return img0
    

###############################################################################
class RotateYUVTest(simtest):

    def testRotateYUV(self):
        """Rotates image through series of rotations and verifies it."""

        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUVTest", "enable", 1)
        self.dev.set("Yuv420Test", "enable", 1)
        self.dev.set("Imager", "enable", 1)

        y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
        self.dev.read("STREAM_INPUT", 0, y)
        yd = (y >> 2).astype(numpy.uint8)
        yd[:,:,1:] += 128
        rgb = numpy.zeros_like(yd)
        ip.YUV2RGB(yd, rgb)
        pylab.imshow(rgb, interpolation='nearest')

        angles =  [0, 15, 45, 75, 90] #numpy.linspace(0,360, 17)
        sincos = []
        
        for idx, angle in enumerate(angles + [0]): # add a dummy at end to get entire sequence
            print "Setting angle=", angle

            sin_theta, cos_theta = rot.set_rotation(angle, self.dev, "RotateYUVTest", bit_depth=8)
            sincos.append((sin_theta, cos_theta))
            
            x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
            self.dev.read("STREAM_OUTPUT", 0, x)
            yuv = numpy.zeros([num_rows-2, num_cols-2,3], dtype=numpy.uint8)
            ip.Stream2YUV(x,yuv)
            #yuv[:,:,1:] += 128
            xd = numpy.zeros_like(yuv)
            ip.YUV2RGB(yuv, xd)

            if idx<1:
                # throw away the first image through the pipeline
                continue
            
            #yR = _rotate(y, sincos[-2][0], sincos[-2][1])
            
            if True:
                #xd =(x>> 2).astype(numpy.uint8)
                #yRd = (yR>>2).astype(numpy.uint8)
                #pylab.figure(figsize=(5,6))
                pylab.figure()
                #pylab.subplot(211)
                pylab.imshow(xd, matplotlib.cm.gray, interpolation='nearest')
                #pylab.subplot(212)
                #pylab.imshow(yRd, matplotlib.cm.gray, interpolation='nearest')
                #break
            
            #import pdb
            #pdb.set_trace()
            #self.assertTrue((x==yR).all(), "Angle=%d failed" % angle)

        pylab.show()

#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
