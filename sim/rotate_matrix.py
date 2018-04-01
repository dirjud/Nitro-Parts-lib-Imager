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
        sin_theta = math.sin(theta)
        cos_theta = math.cos(theta)
        x0 = x0 - num_cols/2
        y0 = y0 - num_rows/2
        
        x = (x0 * cos_theta - y0 * sin_theta) + num_cols/2
        y = (x0 * sin_theta + y0 * cos_theta) + num_rows/2
        return y,x


    def _check(self, xi, yi, theta, num_cols, num_rows):
        bit_depth = 10
        theta = theta * numpy.pi / 180
        num_rows, num_cols = 720, 1280
        
        sin_theta = int(round(math.sin(theta) * (2**(bit_depth-2))))
        cos_theta = int(round(math.cos(theta) * (2**(bit_depth-2))))

        self.dev.set("RotateMatrixTest","cos_theta",cos_theta)
        self.dev.set("RotateMatrixTest","sin_theta",sin_theta)

        self.dev.set("RotateMatrixTest","num_rows",num_rows)
        self.dev.set("RotateMatrixTest","num_cols",num_cols)

        self.dev.set("RotateMatrixTest","xi",xi)
        self.dev.set("RotateMatrixTest","yi",yi)

        xo = _signed(self.dev.get("RotateMatrixTest","xo"), 14) / 4.
        yo = _signed(self.dev.get("RotateMatrixTest","yo"), 14) / 4.

        yC, xC = self._rotate(xi, yi, theta, num_cols, num_rows)
        yC = int(yC * 4)/4.0
        xC = int(xC * 4)/4.0
        
        print "[", yi, xi, "] -> [", yo, xo, "] [", yC, xC, "]"
        self.assertTrue(yo == yC)
        self.assertTrue(xo == xC)
        
    def testRotateMatrix(self):
        """Setup up Rotate Matrix with various input and test output matches expectation."""

        for theta in [0, 10, 45, 90, 180, 270 ]:
        self._check(0,      0, 45, 1280, 720)
        self._check(1279, 719, 45, 1280, 720)
