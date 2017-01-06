import unittest, logging
import testutil

logging.basicConfig(level=logging.INFO)


class simtest(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.tb,cls.dev=testutil.tb_setup(cls.__name__)
        cls.log=logging.getLogger(cls.__name__)

    @classmethod
    def tearDownClass(cls):
        cls.tb.adv(100)

