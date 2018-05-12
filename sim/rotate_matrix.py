from basetest import simtest
import testutil
import logging, random
from nitro_parts.lib.imager import ccm as CCM
import numpy, math

def _signed(x,B):
    if x > (1<<(B-1)):
        return x - (1<<B) + 1
    return x

###############################################################################
class RotateMatrixTest(simtest):

    def _rotate(self, x0, y0, theta, num_cols, num_rows):
        sin_theta = int(round(math.sin(theta)*256))/256.
        cos_theta = int(round(math.cos(theta)*256))/256.
        x0 = x0 - num_cols/2
        y0 = y0 - num_rows/2
        
        x = (x0 * cos_theta - y0 * sin_theta)
        y = (x0 * sin_theta + y0 * cos_theta)

        print "  x0=",x0,"y0=",y0
        print "  x=",x,"y=",y
        x += num_cols/2
        y += num_rows/2
        print "  x=",x,"y=",y
        return y,x


    def _check(self, xi, yi, theta, num_cols, num_rows):
        bit_depth = 10
        theta = theta * numpy.pi / 180
        #num_rows, num_cols = 720, 1280
        
        sin_theta = int(round(math.sin(theta) * (2**(bit_depth-2))))
        cos_theta = int(round(math.cos(theta) * (2**(bit_depth-2))))
        print sin_theta, cos_theta
        
        self.dev.set("RotateMatrixTest","cos_theta",cos_theta)
        self.dev.set("RotateMatrixTest","sin_theta",sin_theta)

        self.dev.set("RotateMatrixTest","num_rows",num_rows)
        self.dev.set("RotateMatrixTest","num_cols",num_cols)

        self.dev.set("RotateMatrixTest","xi",xi)
        self.dev.set("RotateMatrixTest","yi",yi)

        xo = _signed(self.dev.get("RotateMatrixTest","xo"), 14) / 4.
        yo = _signed(self.dev.get("RotateMatrixTest","yo"), 14) / 4.
        xo2 = _signed(self.dev.get("RotateMatrixTest","xo2"), 12)
        yo2 = _signed(self.dev.get("RotateMatrixTest","yo2"), 12)
        xo3 = _signed(self.dev.get("RotateMatrixTest","xo3"), 10) * 4
        yo3 = _signed(self.dev.get("RotateMatrixTest","yo3"), 10) * 4

        yC, xC = self._rotate(xi, yi, theta, num_cols, num_rows)
        yC0 = int(yC * 4)/4.0
        xC0 = int(xC * 4)/4.0
        
        print "[", yi, xi, "] -> [", yo, xo, "] [", yC0, xC0, "]"
        self.assertTrue(yo == yC0)
        self.assertTrue(xo == xC0)


        yC2 = int(yC)
        xC2 = int(xC)
        print "           [", yo2, xo2, "] [", yC2, xC2, "]"
        self.assertTrue(yo2 == yC2)
        self.assertTrue(xo2 == xC2)

        yC3 = int(math.floor(yC/4)*4)
        xC3 = int(math.floor(xC/4)*4)
        print "           [", yo3, xo3, "] [", yC3, xC3, "]"
        self.assertTrue(abs(yo3/4 - yC3/4) < 2)
        self.assertTrue(abs(xo3/4 - xC3/4) < 2)
        
    def testRotateMatrix(self):
        """Setup up Rotate Matrix with various input and test output matches expectation."""

        self._check(0,0,15,218,218)
        self._check(32,-24,-15,218,218)
        self._check(32,-24,15,218,218)
        for theta in [0, 10, 45, 90, 180, 270 ]:
            self._check(0,      0, theta, 1280, 720)
            self._check(1279, 719, theta, 1280, 720)
