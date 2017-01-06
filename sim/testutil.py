import VImager_tb as tb
import os, logging
logging.basicConfig(level=logging.INFO)
log=logging.getLogger(__name__)


debug=os.environ.get("DEBUG", 0) # for vcd generation if debug needed or development.
def tb_setup(name):
    if len(name) and debug:
        tb.init("%s.vcd" % name)
    else:
        tb.init()

    d = {}
    execfile("../terminals.py", d)
    dev = tb.get_dev()
    dev.set_di(d["di"])
    return tb, dev
