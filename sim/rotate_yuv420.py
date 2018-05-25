from basetest import simtest
import testutil
import logging
import numpy, math
import pylab, matplotlib
from nitro_parts.lib.imager import rotate as rot
from videoviewer import imageprocess as ip
import numpy,math,sys
from PIL import Image

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

debug_points = [ [559, 606], [332,563],[893,394] ]

sin_cos_bit_depth = 18
sin_cos_theta_unity = 1<<sin_cos_bit_depth

def _rotate_pos(r, c, theta, num_cols, num_rows):
    cos_theta = int(round(numpy.cos(theta)*sin_cos_theta_unity))/float(sin_cos_theta_unity)
    sin_theta = int(round(numpy.sin(theta)*sin_cos_theta_unity))/float(sin_cos_theta_unity)

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

            for debug_point in debug_points:
                if (row==debug_point[0] and col==debug_point[1]):
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
                for debug_point in debug_points:
                    if (row==debug_point[0] and col==debug_point[1]):
                        print "       c=", c, "r=", r, "sin=", numpy.sin(-theta)*sin_cos_theta_unity, numpy.cos(-theta)*sin_cos_theta_unity
                
                if row <= r < row+1 and col <= c < col+1 and 0 <= p[1] < num_cols and 0 <= p[0] < num_rows:
                    try:
                        c0 = int(c)
                        dc = int((c - c0) * 16)/16.
                        r0 = int(r)
                        dr = int((r - r0) * 16)/16.
                        x1 = (yuv[r0:r0+2,c0]*(1-dc) + yuv[r0:r0+2,c0+1]*dc)
                        x = (x1[0] * (1-dr)) + (x1[1] * dr)
                        for debug_point in debug_points:
                            if (row==debug_point[0] and col==debug_point[1]):
                                print "         y00=",yuv[r0,c0,0], "y01=", yuv[r0,c0+1,0],"y10=",yuv[r0+1,c0,0],"y11=",yuv[r0+1,c0+1,0]
                                print "         dc=", dc, "dr=",dr, "x1=",x1[:,0], "x=",x[0]
                                print "         pR=", p[0], "pC=",p[1]
                    except:
                        x = [0,0,0]

                    if p[0] == 528 and p[1] == 604:
                        print "HERE", row, col
                    if p[0] == 342 and p[1] == 741:
                        print "HERE", row, col
                    if p[0] == 600 and p[1] == 215:
                        print "HERE", row, col
                    mem[p[0],p[1], 0] = x[0]
                    if p[1] & 1: # odd col gets v
                        #mem[p[0],p[1], 1] = kernel_ave[2] #x[2]
                        mem[p[0],p[1], 1] = yuv[r0,c0,2]
                    else: # even col gets u
                        #mem[p[0],p[1], 1] = kernel_ave[1] #x[1]
                        try:
                            mem[p[0],p[1], 1] = yuv[r0,c0+1,1]
                        except IndexError:
                            mem[p[0],p[1], 1] = 128
                            
                        
                        
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




    def _testRotateYUV420(self):
        """Turns on rotation and verifies various angles."""

        num_cols = 1280
        num_rows = 1080
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 300)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_ed", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUV420Test", "enable_420", 1)
        self.dev.set("RotateYUV420Test", "enable_rotate", 1)


#        x0 = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
#        self.dev.read("STREAM_OUTPUT", 0, x0)
#        x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
#        self.dev.read("STREAM_OUTPUT", 0, x)
#        yuv = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint8)
#        ip.Stream2YUV(x, yuv)
#        xd = numpy.zeros_like(yuv)
#        ip.YUV2RGB(yuv, xd)
#
#        #z_yuv = _yuv2yuv420(yd)
#        #z = numpy.zeros_like(z_yuv)
#        #ip.YUV2RGB(z_yuv, z)
#        z_yuv = _rotate_img(yd, 0)
#        self.assertTrue((yuv[6:-6,6:-6] == z_yuv[6:-6,6:-6,0]).all())
        
        angles =  [45]#-(-360/512.-90)]#[0, 15, 45, 75, 90] #numpy.linspace(0,360, 17)
        sincos = []


        for idx, angle in enumerate(angles):# + [25]): # add a dummy at end to get entire sequence
            theta = angle / 180.0 * numpy.pi
            print "Setting angle=", angle

            sin_theta, cos_theta = rot.set_rotation(angle, self.dev, "RotateYUV420Test", bit_depth=sin_cos_bit_depth-2)
            print "  sin,cos=", self.dev.get("RotateYUV420Test","sin_theta"), self.dev.get("RotateYUV420Test","cos_theta")
            sincos.append((sin_theta, cos_theta))

            if idx == 0: # first frame, capture the input image
                self.dev.set("Imager", "enable", 1)
                y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
                self.dev.read("STREAM_INPUT", 0, y)
                yd = (y >> 2).astype(numpy.uint8)
                yd[:,:,1:] += 128
                rgb = numpy.zeros_like(yd)
                ip.YUV2RGB(yd, rgb)
                # drain output fifo
                x = numpy.zeros([1], numpy.uint32)
                self.dev.set("TestBench","debug", 1)
                self.dev.read("STREAM_OUTPUT", 0, x)
                self.dev.set("TestBench","debug", 2)
                pylab.figure(figsize=[8,14])
                pylab.subplots_adjust(top=0.98,bottom=0.02,left=0.01, right=0.99, hspace=0.12)
                ax = pylab.subplot(len(angles)+1,2,1)
                pylab.imshow(rgb, interpolation='nearest')
                pylab.title("Input Image")
            
            x = numpy.zeros((num_rows-2)*(num_cols-2)*3/2, dtype=numpy.uint8)
            self.dev.set("TestBench","debug", 0x100 + idx + 100)

            # stream two images to get push through rotation double buffer
            self.dev.read("STREAM_OUTPUT", 0, x)
            yuv = numpy.zeros([num_rows-2, num_cols-2,3], dtype=numpy.uint8)
            ip.Stream2YUV(x,yuv)
            rgb = numpy.zeros_like(yuv)
            ip.YUV2RGB(yuv, rgb)
            pylab.subplot(len(angles)+1, 2, 2*idx+3, sharex=ax, sharey=ax)
            pylab.imshow(rgb, interpolation="nearest")
            pylab.title("1st Image, Angle=" + str(angle))
            
            self.dev.read("STREAM_OUTPUT", 0, x)
            self.dev.set("TestBench","debug", 0x200 + idx + 100)
            yuv = numpy.zeros([num_rows-2, num_cols-2,3], dtype=numpy.uint8)
            ip.Stream2YUV(x,yuv)
            rgb = numpy.zeros_like(yuv)
            ip.YUV2RGB(yuv, rgb)
            pylab.subplot(len(angles)+1, 2, 2*idx+4, sharex=ax, sharey=ax)
            pylab.imshow(rgb, interpolation="nearest")
            pylab.title("2nd Image, Angle=" + str(angle))

            
            yuvI = _rotate_img(yd, theta)
            rgbI = numpy.zeros_like(yuvI)
            ip.YUV2RGB(yuvI, rgbI)

#            if True:
#                ax = pylab.subplot(131)
#                pylab.imshow(rgb, interpolation="nearest")
#                pylab.subplot(132, sharex=ax, sharey=ax)
#                pylab.imshow(rgbI, interpolation="nearest")
#                pylab.subplot(133, sharex=ax, sharey=ax)
#                pylab.imshow(rgb, interpolation="nearest")
#                pylab.show()
            match = not(((abs(yuv[:,:,0].astype(numpy.int16)-yuvI[:,:,0]) > 2) * (yuv[:,:,0] != 0) * (yuvI[:,:,0] != 0)).any())
            print "    match=",match
            import pdb
            pdb.set_trace()
            #self.assertTrue(match)
        pylab.show()


    def testDebug(self):
        """Turns on rotation and verifies various angles."""

        num_cols = 1282
        num_rows = 1081
        self.dev.set("Imager", "mode", 10)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 300)
        self.dev.set("Imager", "stream_sel", "ROTATE_YUV420")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=2))
        self.dev.set("InterpTest", "phase", 3)
        self.dev.set("InterpTest", "enable_ed", 1)
        self.dev.set("Rgb2YuvTest", "enable", 1)
        self.dev.set("RotateYUV420Test", "enable_420", 1)
        self.dev.set("RotateYUV420Test", "enable_rotate", 1)


        angles =  [45]#-(-360/512.-90)]#[0, 15, 45, 75, 90] #numpy.linspace(0,360, 17)
        sincos = []


        for idx, angle in enumerate(angles):# + [25]): # add a dummy at end to get entire sequence
            theta = angle / 180.0 * numpy.pi

            sin_theta = 48015
            cos_theta = 44604
            theta = numpy.arctan(sin_theta / float(cos_theta))
            angle = theta/numpy.pi*180
            print "Setting angle=", angle
            
            self.dev.set("RotateYUV420Test","cos_theta",cos_theta)
            self.dev.set("RotateYUV420Test","sin_theta",sin_theta)
            #sin_theta, cos_theta = rot.set_rotation(angle, self.dev, "RotateYUV420Test", bit_depth=sin_cos_bit_depth-2)
            print "  sin,cos=", self.dev.get("RotateYUV420Test","sin_theta"), self.dev.get("RotateYUV420Test","cos_theta")
            sincos.append((sin_theta, cos_theta))

            if idx == 0: # first frame, capture the input image
                self.dev.set("Imager", "enable", 1)
                y = numpy.zeros([num_rows-2, num_cols-2, 3], dtype=numpy.uint16)
                self.dev.read("STREAM_INPUT", 0, y)
                yd = (y >> 2).astype(numpy.uint8)
                yd[:,:,1:] += 128
                rgb = numpy.zeros_like(yd)
                ip.YUV2RGB(yd, rgb)
                # drain output fifo
                x = numpy.zeros([1], numpy.uint32)
                self.dev.set("TestBench","debug", 1)
                self.dev.read("STREAM_OUTPUT", 0, x)
                self.dev.set("TestBench","debug", 2)
            
            yuvI = _rotate_img(yd, theta)
            x = numpy.zeros([(num_rows-2)*(num_cols-2),3], dtype=numpy.uint8)
            self.dev.read("STREAM_OUTPUT", 0, x)
            z = numpy.zeros([(num_rows-2),(num_cols-2)], dtype=numpy.uint8)
            addrs = []
            for idx in range(x.shape[0]):
                addr = (x[idx][0] << 16) + (x[idx][1] << 8) + x[idx][2]
                row = addr / (num_cols-2)
                col = addr - row*(num_cols-2)
                z[row,col]=255
                addrs.append(addr)
                #if addr == 528*(num_cols-2) + 604:
                #    import pdb
                #    pdb.set_trace()
                prev_addr = addr
            pylab.imshow(z)
            pylab.show()


        
if __name__ == "__main__":
    ifile = "chart_1280x720.png"
    ofile = "chart_1280x720_rotated.png"

    im = Image.open(ifile)
    rgb = numpy.array(im)
    print rgb.shape
    if rgb.shape[2] == 4:
        rgb = rgb[:,:,:3].copy()
    yuv = numpy.zeros_like(rgb)
    ip.RGB2YUV(rgb, yuv)

    num_rows, num_cols, depth = rgb.shape
    yuvI = _rotate_img(yuv, -92.8125)
    rgbI = numpy.zeros_like(yuvI)
    ip.YUV2RGB(yuvI, rgbI)
    pylab.imshow(rgbI, interpolation="nearest")
    pylab.show()
