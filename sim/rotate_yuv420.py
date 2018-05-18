from basetest import simtest
import testutil
import logging
import numpy, math
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from videoviewer import imageprocess as ip

#def _rotate_img(img, sin_theta, cos_theta):
#    img0 = numpy.zeros_like(img)
#    num_rows, num_cols = img.shape
#    for row in range(num_rows):
#        for col in range(num_cols):
#            col0 = col - num_cols/2
#            row0 = row - num_rows/2
#
#            col1 = int((col0 * cos_theta - row0 * sin_theta) * 256)
#            row1 = int((col0 * sin_theta + row0 * cos_theta) * 256)
#
#            col2 = col1 / 256
#            row2 = row1 / 256
#
#            col3 = col2 + num_cols/2
#            row3 = row2 + num_rows/2
#            
#            #perserve the bayer phase by perserving the LSB
#            col4 = (col3 & 0xFFFFFFFE) | (col & 0x00000001)
#            row4 = (row3 & 0xFFFFFFFE) | (row & 0x00000001)
#
#            ob = not(row4 >= 0 and col4 >= 0 and row4 < num_rows and col4 < num_cols)
#            if not(ob):
#                img0[row, col] = img[row4, col4]
#
#            #if(col >= 565 and col < 585 and row == 0):
#            #    print "col =", col, "col0=", col0,"col1=", col1,"col2=", col2,"col3=", col3,"col4=", col4,
#            #    print " row=", row, "row0=", row0,"row1=", row1,"row2=", row2,"row3=", row3,"row4=", row4,
#            #    print " ob=", ob, "out=", img0[row,col]
#    return img0

def _rotate_pos(r, c, theta, num_cols, num_rows):
    cos_theta = int(round(numpy.cos(theta)*256))/256.
    sin_theta = int(round(numpy.sin(theta)*256))/256.

    col0 = c - num_cols/2.0
    row0 = r - num_rows/2.0

    c1 = (col0 * cos_theta - row0 * sin_theta) + num_cols/2.0
    r1 = (col0 * sin_theta + row0 * cos_theta) + num_rows/2.0
    return r1, c1


def _rotate_img(yuv, theta):
#    img0 = numpy.zeros_like(img)
    num_rows, num_cols = yuv.shape[:2]
    mem = numpy.zeros_like(yuv)
    for row in range(num_rows):
        for col in range(num_cols):
            colC = col + 0.5
            rowC = row + 0.5

            # find four nearest integer coordinate locations in rotated space
            rowCr, colCr = _rotate_pos(rowC, colC, theta, num_cols, num_rows)
    
            rowCr0 = int(math.floor(rowCr))
            rowCr1 = rowCr0 + 1
            colCr0 = int(math.floor(colCr))
            colCr1 = colCr0 + 1

            if (row==0 and col==0) or (row==100 and col==100):
                print "  angle=", theta/numpy.pi * 180, "colCr0=", colCr0, "rowCr0=", rowCr0, col, row
            
            kernel = [ [rowCr0,colCr0], [rowCr0,colCr1], [rowCr1,colCr0], [rowCr1,colCr1]]

            # average the 4 pixel kernel in the unrotated domain so that we
            # can use their u and v channel
            kernel_ave = numpy.array([0,0,0], dtype=numpy.uint16)
            c = 0
            for p in kernel:
                if 0 <= p[1] < num_cols and 0 <= p[0] < num_rows:
                    kernel_ave += yuv[p[0], p[1]]
                    c += 1
            if c > 0:
                kernel_ave = kernel_ave / c
            else:
                kernel_ave = [128,128,128]

            # now unrotate the 4 integer coordinates back into the unrotated
            # space so we can see which ones should be interpolated by this
            # kernel. 0, 1, or 2 rotated pixels may need to be generated.
            # The verilog will need to stuff those pixels and their
            # address into a buffer that can write them out to RAM
            for p in kernel:
                r,c=_rotate_pos(p[0], p[1], -theta, num_cols, num_rows)
                if (row==0 and col==0) or (row==100 and col==100):
                    print "       c=", c, "r=", r, "sin=", numpy.sin(-theta)*256, numpy.cos(-theta)*256
                
                if row <= r < row+1 and col <= c < col+1 and 0 <= p[1] < num_cols and 0 <= p[0] < num_rows:
                    try:
                        c0 = int(c)
                        dc = c - c0
                        r0 = int(r)
                        dr = r - r0
                        x1 = (yuv[r0:r0+2,c0]*(1-dc) + yuv[r0:r0+2,c0+1]*dc)
                        x = (x1[0] * (1-dr)) + (x1[1] * dr)
                        if (row==0 and col==0) or (row==100 and col==100):
                            print "         y00=",yuv[r0,c0,0], "y01=", yuv[r0,c0+1,0],"y10=",yuv[r0+1,c0,0],"y11=",yuv[r0+1,c0+1,0]
                            print "         dc=", dc, "dr=",dr, "x1=",x1[:,0], "x=",x[0]
                            print "         pR=", p[0], "pC=",p[1]
                    except:
                        x = [0,0,0]
    
                    mem[p[0],p[1], 0] = x[0]
                    if p[1] & 1: # odd col gets v
                        mem[p[0],p[1], 1] = kernel_ave[2] #x[2]
                    else: # even col gets u
                        mem[p[0],p[1], 1] = kernel_ave[1] #x[1]
                        
                        
    # now read out the image into YUV420 format
    mem2 = []
    for row in range(num_rows):
        for col in range(num_cols):
    
            r,c=_rotate_pos(row, col, -theta, num_cols, num_rows)
            
            if(0 <= r < num_rows and 0 <= c < num_cols): # check if pixel is in range
                
                mem2.append(mem[row,col,0]) # always write the y component
                if (row & 1) and (col & 1): # append u,v on odd rows/odd col
                    mem2.append(mem[row,col-1,1])
                    #mem2.append(mem[row,col,2])
                    mem2.append(mem[row,col,1])
            else: # if out of range, set pixel to black
                mem2.append(0)
                if (row & 1) and (col & 1): # append u,v on odd rows/odd col
                    mem2.append(128)
                    mem2.append(128)
    
    mem2=numpy.array(mem2,dtype=numpy.uint8)
    yuvo = numpy.zeros_like(yuv)
    ip.Stream2YUV(mem2, yuvo)
    return yuvo


def _yuv2yuv420(yd):
    z_yuv = numpy.zeros_like(yd)
    z_yuv[:,:,0] = yd[:,:,0] # copy the y channel
    uv = ((yd[0::2,0::2,1:].astype(int) + yd[1::2,0::2,1:] + yd[0::2,1::2,1:] + yd[1::2,1::2,1:]) / 4).astype(numpy.uint8)
    z_yuv[0::2,0::2,1:] = uv
    z_yuv[1::2,0::2,1:] = uv
    z_yuv[0::2,1::2,1:] = uv
    z_yuv[1::2,1::2,1:] = uv
    return z_yuv
    

###############################################################################
class RotateYUV420Test(simtest):

    def _testYUV444(self):
        """Turns off rotation and yuv420 tests that yuv444 pass-through works"""

        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUV420Test", "enable_420", 0)
        self.dev.set("RotateYUV420Test", "enable_rotate", 0)
        self.dev.set("Imager", "enable", 1)

        y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
        self.dev.read("STREAM_INPUT", 0, y)
        yd = (y >> 2).astype(numpy.uint8)
        yd[:,:,1:] += 128
        rgb = numpy.zeros_like(yd)
        ip.YUV2RGB(yd, rgb)
        pylab.imshow(rgb, interpolation='nearest')
        #pylab.show()

        yuv = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint8)
        self.dev.read("STREAM_OUTPUT", 0, yuv)
        yuv[:,:,1:] += 128
        xd = numpy.zeros_like(yuv)
        ip.YUV2RGB(yuv, xd)

        self.assertTrue((yd == yuv).all())


    def _testYUV420(self):
        """Turns off rotation and verifies 420 comes through."""

        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUV420Test", "enable_420", 1)
        self.dev.set("RotateYUV420Test", "enable_rotate", 0)
        self.dev.set("Imager", "enable", 1)

        y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
        self.dev.read("STREAM_INPUT", 0, y)
        yd = (y >> 2).astype(numpy.uint8)
        yd[:,:,1:] += 128
        rgb = numpy.zeros_like(yd)
        ip.YUV2RGB(yd, rgb)
        pylab.imshow(rgb, interpolation='nearest')
        #pylab.show()

        x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
        self.dev.read("STREAM_OUTPUT", 0, x)
        yuv = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint8)
        ip.Stream2YUV(x, yuv)
        xd = numpy.zeros_like(yuv)
        ip.YUV2RGB(yuv, xd)

        z_yuv = _yuv2yuv420(yd)
        z = numpy.zeros_like(z_yuv)
        ip.YUV2RGB(z_yuv, z)
        self.assertTrue((yuv == z_yuv).all())

    def testRotateYUV420(self):
        """Turns on rotation and verifies various angles."""

        num_cols = 220
        num_rows = 220
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUV420Test", "enable_420", 1)
        self.dev.set("RotateYUV420Test", "enable_rotate", 1)
        self.dev.set("Imager", "enable", 1)

        y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
        self.dev.read("STREAM_INPUT", 0, y)
        yd = (y >> 2).astype(numpy.uint8)
        yd[:,:,1:] += 128
        rgb = numpy.zeros_like(yd)
        ip.YUV2RGB(yd, rgb)
        pylab.imshow(rgb, interpolation='nearest')
        #pylab.show()

        x0 = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
        self.dev.read("STREAM_OUTPUT", 0, x0)
        x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
        self.dev.read("STREAM_OUTPUT", 0, x)
        yuv = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint8)
        ip.Stream2YUV(x, yuv)
        xd = numpy.zeros_like(yuv)
        ip.YUV2RGB(yuv, xd)

        z_yuv = _yuv2yuv420(yd)
        z = numpy.zeros_like(z_yuv)
        ip.YUV2RGB(z_yuv, z)

        import pdb
        pdb.set_trace()
        self.assertTrue((yuv[:-2,:-1,0] == z_yuv[:-2,:-1,0]).all())
        
        
        angles =  [15]#[0, 15, 45, 75, 90] #numpy.linspace(0,360, 17)
        sincos = []
        
        for idx, angle in enumerate(angles + [0]): # add a dummy at end to get entire sequence
            theta = angle / 180.0 * numpy.pi
            print "Setting angle=", angle

            sin_theta, cos_theta = rot.set_rotation(angle, self.dev, "RotateYUV420Test", bit_depth=8)
            sincos.append((sin_theta, cos_theta))
            
            x0 = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
            self.dev.read("STREAM_OUTPUT", 0, x0)
            x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
            self.dev.read("STREAM_OUTPUT", 0, x)
            self.dev.read("STREAM_OUTPUT", 0, x)
            yuv = numpy.zeros([num_rows-2, num_cols-2,3], dtype=numpy.uint8)
            ip.Stream2YUV(x,yuv)
            #yuv[:,:,1:] += 128
            xd = numpy.zeros_like(yuv)
            ip.YUV2RGB(yuv, xd)


            yuvI = _rotate_img(yd, theta)

            print "    READ 99,103 -> Y =", yuv[99,103,0]
#if __name__ == "__main__":
#    rt = RotateTest()
#    rt.testRotate()
