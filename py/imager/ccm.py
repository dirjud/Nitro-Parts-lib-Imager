

def set_ccm(dev, matrix, term="FPGA", coeff_width=8, coeff_frac_width=5, regs=[["RR","RG","RB"],["GR","GG","GB"],["BR","BG","BB"],]):
    """Matrix should be a 3x3 list of lists as floats. This will convert
    the matrix coeffs to fixed point and write them to the device
    registers.

    Matrix should be of the form [ RR RG RB ]
                                 [ GR GG GB ]
                                 [ BR BG BB ]
    
    so that if the input is [r g b], the output will be
    [ r*RR+g*RG+b*RB r*GR+g*GG+b*GB r*BR+g*BG+b*BB ]
    """

    omatrix = []
    for rline, mline in zip(regs, matrix):
        oline = []
        omatrix.append(oline)
        for reg, m in zip(rline, mline):
            v = int(round(m * 2**coeff_frac_width)) & ((1<<coeff_width) - 1)
            dev.set(term, reg, v)
            if v >> (coeff_width-1): # negative
                mo = v - (1 << coeff_width)
            else:
                mo = v
            mo = mo / float(2**coeff_frac_width)
            oline.append(mo)
    return omatrix
