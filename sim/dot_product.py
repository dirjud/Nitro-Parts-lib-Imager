from basetest import simtest
import testutil
import logging, random
from nitro_parts.lib.imager import ccm as CCM
import numpy


###############################################################################
class DotProductTest(simtest):

    def _set_coeff(self, c):
        cq = (c * 32).astype(numpy.uint8)
        self.dev.set("DotProductTest","c0", cq[0])
        self.dev.set("DotProductTest","c1", cq[1])
        self.dev.set("DotProductTest","c2", cq[2])
        return cq
        
    def _set_data(self, d):
        self.dev.set("DotProductTest","d0", d[0])
        self.dev.set("DotProductTest","d1", d[1])
        self.dev.set("DotProductTest","d2", d[2])

    def _check(self, c, d):
        d = numpy.array(d)
        ds = d.copy()
        ds[d>511] = d[d>511] - 1024

        c = numpy.array(c)
        cq = self._set_coeff(c)
        cs = cq.astype(numpy.int8)
        cs[cq>127] = cq[cq>127] - 256
        
        self._set_data(d)
        do = self.dev.get("DotProductTest","datao_uu")
        data_uu = min(1023, sum(cq * d)/32)
        #print "UU", do, data_uu
        self.assertTrue( do == data_uu, "UU")

        data_su = max(0, min(1023, sum(cs * d)/32))
        do = self.dev.get("DotProductTest", "datao_su")
        #print "SU", d, cs, do, data_su
        self.assertTrue( do == data_su, "SU " + str(d) + " " + str(cs) + " " + str(do) + " " + str(data_su))

        data_us = max(-512, min(511, sum(cq * ds)/32))
        do = self.dev.get("DotProductTest", "datao_us")
        if(do > 511): do = do - 1024
        #print "US", do, ds, data_us
        self.assertTrue( do == data_us, "US")

        data_ss = max(-512, min(511, sum(cs * ds)/32))
        do = self.dev.get("DotProductTest", "datao_ss")
        if(do > 511): do = do - 1024
        #print "SS", ds, cq, cs, do, data_ss
        self.assertTrue( do == data_ss, "SS")
        
    def testDotProduct(self):
        """Setup up Dot Product with various input and test output matches expectation."""

        self._check([0.000, 1.000, 0.000], [ 1023, 1023, 1023 ])
        self._check([0.125, 0.750, 0.125], [ 1023, 1023, 1023 ])
        self._check([1/32., 1.000, 0.000], [ 1023, 1023, 1023 ])
        self._check([1.000, 1.000, 1.000], [ 1023, 1023, 1023 ])
        self._check([0, 0, 0], [ 1023, 1023, 1023 ])
        self._check([1/32., 0, 0], [ 1, 100, 100 ])
        self._check([1.0, 0, 0],   [ 1, 100, 100 ])
        self._check([0, 1.0, 0],   [ 1, 100, 100 ])
        self._check([0, 0, 1.0],   [ 1, 100, 100 ])
        self._check([1.000, 1.000, 1.000], [ 513, 513, 513 ])
        self._check([1.000, 1.000, 1.000], [ 512, 512, 512 ])
        self._check([1.000, 1.000, 1.000], [ 0, 512, 0 ])

        self._check([0.000, 1.5, 0.000], [ 0, 680, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 681, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 682, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 683, 0 ])

        self._check([0.000, 1.5, 0.000], [ 0, 339, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 340, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 341, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 342, 0 ])

        self._check([0.000, 1.5, 0.000], [ 0, 1023-338, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 1023-339, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 1023-340, 0 ])
        self._check([0.000, 1.5, 0.000], [ 0, 1023-341, 0 ])

        self._check([0.000, -1.0, 0.000], [ 0, 500, 0 ])
        self._check([1/32., -1.0, 1/32.], [ 500, 500, 500 ])
        self._check([-1/32., -1.0, -1/32.], [ 400, 400, 400 ])

        for idx in range(100):
            data  = [ random.randint(0,1023) for r in range(3) ]
            coeff = [ max(-2.0, min(127/32., random.random() * 4 - 2)) for r in range(3) ]
            #print coeff, data
            self._check(coeff, data)
