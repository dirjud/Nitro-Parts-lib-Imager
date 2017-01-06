import unittest, time, sys

if __name__ == '__main__':
    logfile = "Imager Unit Tests.txt" 
    f=open(logfile,'w')
    runner=unittest.TextTestRunner(f,verbosity=4)
    unittest.main(module=None,testRunner=runner)
    f.close()

