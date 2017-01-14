import numpy, pylab, matplotlib, math
from PIL import Image

num_cols = 1280
num_rows = 720

y = ((numpy.arange(0,num_cols).repeat(num_rows).reshape(num_cols,num_rows).transpose() + numpy.arange(0,num_rows).repeat(num_cols).reshape(num_rows,num_cols)) & 0xFF).astype(numpy.uint8)

pylab.figure()
pylab.imshow(y, matplotlib.cm.gray, interpolation="nearest")

B = 16
thetas = numpy.linspace(0, 360, B+1)[:B]

def rotate(sin_theta, cos_theta):
    img = numpy.zeros_like(y)

    for row in range(num_rows):
        for col in range(num_cols):
            col0 = col - num_cols/2
            row0 = row - num_rows/2

            col1 = int(round((col0 * cos_theta - row0 * sin_theta) + num_cols/2))
            row1 = int(round((col0 * sin_theta + row0 * cos_theta) + num_rows/2))

            if row1 >= 0 and col1 >= 0 and row1 < num_rows and col1 < num_cols:
                img[row, col] = y[row1, col1]
    return img


for idx, theta in enumerate(thetas[0:2]):
    print idx, theta
    
    sin_theta = numpy.sin(theta/180*math.pi)
    cos_theta = numpy.cos(theta/180*math.pi)

    img_float = rotate(sin_theta, cos_theta)
    im = Image.fromarray(img_float)
    im.save("data/img_%03d_ideal.png" % (idx,))

    for B in [7, 8, 9, 10]:
        sin1 = round(sin_theta * 2**B)/2**B
        cos1 = round(cos_theta * 2**B)/2**B
        sin2 = max(-1.0, min(1-1.0/(2**(B-1)), sin1))
        cos2 = max(-1.0, min(1-1.0/(2**(B-1)), cos1))

        print "  B=", B, sin1, sin_theta, cos1, cos_theta
        img = rotate(sin2, cos2)
        im = Image.fromarray(img)
        im.save("data/img_%03d_%02db.png" % (idx,B))

        if(theta == 0):
            img = rotate(sin1, cos1)
            im = Image.fromarray(img)
            im.save("data/img_%03d_%02db_fs.png" % (idx,B))
        
        
