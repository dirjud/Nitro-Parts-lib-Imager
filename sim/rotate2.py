from PIL import Image
from videoviewer import imageprocess as ip

im = Image.open("chart_1280x720.png")
rgb = numpy.asarray(im, dtype=numpy.uint8).copy()
rgb[100:120,100:120,:] = [255,0,0]
rgb[120:140,100:120,:] = [0,255,0]
rgb[140:160,100:120,:] = [0,0,255]

yuv = numpy.zeros_like(rgb)
ip.RGB2YUV(rgb, yuv)


def _rotate(img, theta):
    img0 = numpy.zeros_like(img)
    num_rows, num_cols, depth = img.shape
    cos_theta = numpy.cos(theta / 180. * numpy. pi)
    sin_theta = numpy.cos(theta / 180. * numpy. pi)
    for row in range(num_rows):
        for col in range(num_cols):
            col0 = col - num_cols/2
            row0 = row - num_rows/2

            col1 = int(round(col0 * cos_theta - row0 * sin_theta))
            row1 = int(round(col0 * sin_theta + row0 * cos_theta))

            col3 = col1 + num_cols/2
            row3 = row1 + num_rows/2
            
            ob = not(row3 >= 0 and col3 >= 0 and row3 < num_rows and col3 < num_cols)
            if not(ob):
                img0[row, col] = img[row3, col3]

    return img0


yuv45 = _rotate(yuv, 45)
rgb45 = numpy.zeros_like(yuv45)
ip.YUV2RGB(yuv45, rgb45)

pylab.figure(figsize=[24,8])
pylab.subplots_adjust(left=0.0, right=1.0, bottom=0.04, top=1.0, wspace=0.0)
ax = pylab.subplot(121)
pylab.imshow(rgb, interpolation="nearest")
pylab.subplot(122, sharex=ax, sharey=ax)
pylab.imshow(rgb45, interpolation="nearest")


yuv2 = yuv.copy()
yuv2[:,0::2,1:] = ((yuv[:,0::2,1:].astype(int) + yuv[:,1::2,1:])/2).astype(numpy.uint8)
yuv2[:,1::2,1:] = yuv2[:,0::2,1:]
rgb2 = numpy.zeros_like(yuv2)
ip.YUV2RGB(yuv2, rgb2)

pylab.figure(figsize=[24,8])
pylab.subplots_adjust(left=0.0, right=1.0, bottom=0.04, top=1.0, wspace=0.0)
ax = pylab.subplot(121)
pylab.imshow(rgb, interpolation="nearest")
pylab.subplot(122, sharex=ax, sharey=ax)
pylab.imshow(rgb2, interpolation="nearest")


def _rotate2(img, theta):
    img0 = numpy.zeros_like(img)
    num_rows, num_cols, depth = img.shape
    cos_theta = numpy.cos(theta / 180. * numpy. pi)
    sin_theta = numpy.cos(theta / 180. * numpy. pi)
    fault=count=0
    for row in range(num_rows):
        for col in range(num_cols):
            col0 = col - num_cols/2
            row0 = row - num_rows/2

            col1 = int(round(col0 * cos_theta - row0 * sin_theta))
            row1 = int(round(col0 * sin_theta + row0 * cos_theta))

            col3 = col1 + num_cols/2
            row3 = row1 + num_rows/2
            
            ob = not(row3 >= 0 and col3 >= 0 and row3 < num_rows and col3 < num_cols)
            if not(ob):
                count += 1
                img0[row, col,0] = img[row3, col3,0]
                if col & 0x1: # v output col
                    if col3 & 0x1: # v input column
                        img0[row, col, 2] = img[row3, col3, 2]
                    else: # u input column
                        if(col3-1 >= 0):
                            img0[row, col, 2] = img[row3, col3-1, 2]
                            fault += 1
                else: # u output column
                    if col3 & 0x1: # v input column
                        if(col3+1 < num_cols):
                            img0[row, col, 1] = img[row3, col3+1, 1]
                            fault += 1
                    else: # u input column
                        img0[row, col, 1] = img[row3, col3, 1]

    print "Fault Percent=", fault/float(count)
    img0[:,0::2,2] = img0[:,1::2,2]
    img0[:,1::2,1] = img0[:,0::2,1]
    return img0

yuv2_45 = _rotate2(yuv2, 45)
rgb2_45 = numpy.zeros_like(yuv2_45)
ip.YUV2RGB(yuv2_45, rgb2_45)
pylab.figure(figsize=[24,8])
pylab.subplots_adjust(left=0.0, right=1.0, bottom=0.04, top=1.0, wspace=0.005)
ax = pylab.subplot(121)
pylab.imshow(rgb45, interpolation="nearest")
pylab.subplot(122, sharex=ax, sharey=ax)
pylab.imshow(rgb2_45, interpolation="nearest")
