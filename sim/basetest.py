import unittest, logging
import testutil
import numpy, pylab, matplotlib

logging.basicConfig(level=logging.INFO)


class simtest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tb,cls.dev=testutil.tb_setup(cls.__name__)
        cls.log=logging.getLogger(cls.__name__)

    @classmethod
    def tearDownClass(cls):
        cls.tb.adv(100)


def raw_plot_img(x, B=10):
    xd =(x>>(B-8)).astype(numpy.uint8)
    pylab.imshow(xd, matplotlib.cm.gray, interpolation='nearest')


def get_input_and_output_imgs(dev, num_rowsi, num_colsi, num_rowso=None, num_colso=None):
    x = numpy.zeros([num_rowsi, num_colsi], dtype=numpy.uint16)
    dev.read("STREAM_INPUT", 0, x)

    if num_colso is None:
        num_colso = num_colsi
    if num_rowso is None:
        num_rowso = num_rowsi
    y = numpy.zeros([num_rowso, num_colso], dtype=numpy.uint16)
    dev.read("STREAM_OUTPUT", 0, y)

    return x,y
