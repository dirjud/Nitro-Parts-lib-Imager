import basetest
import testutil
import logging, random
from nitro_parts.lib.imager import rotate as rot
from videoviewer import imageprocess as ip

###############################################################################
class LookupMapTest(basetest.simtest):

    def testLookupMap(self):
        """Sets lookup map and verifies input translates correctly. Checks both enabled and disabled"""
        num_cols = 200
        num_rows = 20
        self.dev.set("Imager", "mode", 0)
        self.dev.set("Imager", "num_active_cols", num_cols)
        self.dev.set("Imager", "num_active_rows", num_rows)
        self.dev.set("Imager", "num_virtual_rows", 50) # give enough time to read images prior to starting next one to prevent split images when parameters change
        self.dev.set("Imager", "stream_sel", "LOOKUP_MAP")
        self.dev.set("Imager", "capture", dict(modei=1, modeo=1))
        self.dev.set("InterpTest", "enable_bilinear", 1)
        self.dev.set("Rgb2YuvTest",        "enable", 1)

        lu = [ random.randint(0,1023) for i in range(1024) ]
        for idx, val in enumerate(lu):
            self.dev.set("LookupMap", idx, val)
        self.dev.set("Imager", "enable", 1)

        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-2, num_cols-2, depthi=3, deptho=3)
        self.assertTrue((x==y).all())

        self.dev.set("LookupMapTest", "enable", 1)
        x,y = basetest.get_input_and_output_imgs(self.dev, num_rows-2, num_cols-2, num_rows-2, num_cols-2, depthi=3, deptho=3)

        self.assertTrue((x[:,:,1:]==y[:,:,1:]).all())
        for x1,y1 in zip(x[:,:,0][0],y[:,:,0][0]):
            self.assertTrue(lu[x1] == y1)
