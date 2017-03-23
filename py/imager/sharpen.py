
def set_strength(dev, strength, term="ImageProcessPipeline", regs=["sharpen_c0","sharpen_c1", "sharpen_c2"]):

    c2 = strength * 32.
    c1 = -((strength - 1.0) / 4.) * 32
    c0 = c1
    dev.set(term, regs[0], c0)
    dev.set(term, regs[1], c1)
    dev.set(term, regs[2], c2)
