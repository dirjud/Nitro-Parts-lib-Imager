
def set_unsharp_mask(dev, strength, threshold, term="ImageProcessPipeline", regs=["sharpen_c0","sharpen_c1", "sharpen_c2"], threshold_reg="threshold", one=32):

    c2 = int((strength-1) * one)
    c1 = -int(c2/4)
    c0 = c1
    dev.set(term, regs[0], c0)
    dev.set(term, regs[1], c1)
    dev.set(term, regs[2], c2)
    dev.set(term, threshold_reg, threshold)
