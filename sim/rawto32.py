from basetest import *
import testutil, numpy
from nitro_parts.lib.imager import raw10

class RawTo32Test(simtest):

    def tearDown(self):
        self.dev.set('RawTo32Test','en',0)

    def _init(self,r,c):
        self.dev.set('Imager','enable',0)
        self.dev.set('RawTo32Test','en',1)
        self.dev.set('Imager','mode',3)
        self.dev.set('Imager','capture',dict(modei=0,modeo=2))

        # self.dev.set('Imager','bayer_red',0x3ff)
        # self.dev.set('Imager','bayer_gr', 0x0)
        # self.dev.set('Imager','bayer_blue',0x3)
        # self.dev.set('Imager','bayer_gb',0x0)
        self.dev.set('Imager','num_active_rows',r)
        self.dev.set('Imager','num_active_cols',c)
        self.dev.set("Imager", "num_virtual_rows", 30)
        self.dev.set('Imager', 'stream_sel', 'RAWTO32')

    def _testPacked(self,r,c):

        self._init(r,c)
        self.dev.set('RawTo32Test','pack',1)
        self.dev.set('Imager','enable',1)

        i = numpy.zeros((r,c),dtype=numpy.uint16)
        self.dev.read('STREAM_INPUT',0,i)

        o = numpy.zeros((r,raw10.packed_cols(c)),dtype=numpy.uint8)
        self.dev.read('STREAM_OUTPUT',0,o)

        o2 = raw10.unpack(o)

        self.assertTrue (
            (i[:,:o2.shape[1]] == o2).all(),
            "unexpected output"
        )

    def testPack(self):
        """
            Packed data with no remainder bytes
        """
        self._testPacked(20,96)

    def testPackRemainder(self):
        self._testPacked(20,100)

    def test16b(self):
        r=20
        c=100
        self._init(r,c)
        self.dev.set('RawTo32Test','pack',0)
        self.dev.set('Imager','enable',1)

        i = numpy.zeros((r,c),dtype=numpy.uint16)
        self.dev.read('STREAM_INPUT',0,i)

        o = numpy.zeros((r,c),dtype=numpy.uint16)
        self.dev.read('STREAM_OUTPUT',0,o)

        self.assertTrue(
            (i == o).all(),
            "unexpected output"
        )
