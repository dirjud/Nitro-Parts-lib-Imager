from basetest import simtest
import testutil
import logging
from nitro_parts.lib.imager import ccm as CCM
import numpy

matrixs = [
    [ [ 1.0,  0.0,  0.0 ], [  0.0, 1.0,  0.0 ], [  0.0, 0.0, 1.0 ] ], # unity
    [ [ 1.3, -0.1, -0.2 ], [ -0.5, 1.8, -0.2 ], [  0.2, 0.2, 1.5 ] ],
    [ [ 0.5, 0.05, 0.01 ], [ 0.05, 0.3, -0.2 ], [  0.2, 0.2, 0.2 ] ],
]

###############################################################################
class CcmTest(simtest):

    def testCCM(self):
        """Setup up CCM with various matrices and runs a range of inputs through to verify output matches numpy calculations."""

        self.dev.set("CcmTest", "enable", 1)
        for matrix in matrixs:
            self._testMatrix(matrix)

    def _testMatrix(self, matrix):
        m = CCM.set_ccm(self.dev, matrix, term="CcmTest")
        m = numpy.matrix(m).transpose()

        m0 = numpy.matrix(matrix).transpose()

        self.assertTrue( abs(m0-m).max() < 1/64., "Matrix error")
        
        values = [ 0x00, 0x155, 0x2AA, 0x3FF ]

        #print m
        for ri in values:
            self.dev.set("CcmTest","ri", ri)
            for gi in values:
                self.dev.set("CcmTest","gi", gi)
                for bi in values:
                    self.dev.set("CcmTest","bi", bi)
                    self.dev.set("CcmTest","dvi", 1)

                    ro = self.dev.get("CcmTest","ro")
                    go = self.dev.get("CcmTest","go")
                    bo = self.dev.get("CcmTest","bo")

                    rgbo = numpy.matrix([ri, gi, bi]) * m
                    r0, g0, b0 = [ max(0, min(1023, int(x))) for x in numpy.array(rgbo)[0] ]

                    #print ri, r0, ro, gi, g0, go, bi, b0, bo

                    self.assertTrue(ro == r0, "Red error r0=0x%x ro=0x%x." % (r0, ro))
                    self.assertTrue(go == g0, "Green error g0=0x%x go=0x%x." % (g0, go))
                    self.assertTrue(bo == b0, "Blue error b0=0x%x bo=0x%x." % (b0, bo))
                    
