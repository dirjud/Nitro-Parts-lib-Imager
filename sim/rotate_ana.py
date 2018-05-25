import numpy
from videoviewer import imageprocess as ip

num_cols = 1278
num_rows = 1078

f=open("rotate.txt","rb")
imgs = []
for l in f:
    l = l.strip()
    if l=="START":
        img = numpy.zeros([num_rows,num_cols], dtype=numpy.uint8)
        continue
    if l=="END":
        imgs.append(img)
        continue
    
    x = eval(l)
    addr = x >> 16
    r = addr/num_cols
    c = addr - r*num_cols
    img[r,c] = 255

    
for img in imgs:
    pylab.figure()
    pylab.imshow(img)
    
f=open("rotate_out.txt","rb")
o_imgs = []
for l in f:
    l = l.strip()
    if l=="START":
        data = []

    elif l=="END":
        yuv = numpy.zeros([num_rows,num_cols,3],dtype=numpy.uint8)
        ip.Stream2YUV(numpy.array(data, dtype=numpy.uint8), yuv)
        rgb = numpy.zeros_like(yuv)
        ip.YUV2RGB(yuv, rgb)
        imgs.append(rgb)
        continue
    else:
        x = eval(l)
        data.append((x >> 0)  & 0xFF)
        data.append((x >> 8)  & 0xFF)
        data.append((x >> 16) & 0xFF)
        data.append((x >> 24) & 0xFF)

for img in imgs:
    pylab.figure()
    pylab.imshow(img)
    
