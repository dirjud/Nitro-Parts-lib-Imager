import numpy

def set_ccm(dev, matrix, term="FPGA", coeff_width=8, coeff_frac_width=5, regs=[["RR","GR","BR"],["RG","GG","BG"],["RB","GB","BB"],]):
    """Matrix can be either a 3x3 list of lists or a 3x3 numpy
    array. Either way it should be floats. This will convert the
    matrix coeffs to fixed point and write them to the device
    registers.

    Matrix should be of the form [ RR GR BR ]
                                 [ RG GG BG ]
                                 [ RB GB BB ]
    
    so that if the input is [r g b], the output will be
    [ r*RR+g*RG+b*RB r*GR+g*GG+b*GB r*BR+g*BG+b*BB ]

    """

    if type(matrix) is list:
        matrix = numpy.array(matrix)

    if matrix.shape != (3,3):
        raise Exception("Matrix must be 3x3")
        
    f = ccm_float2fixed(matrix, coeff_width, coeff_frac_width)
    for rline, mline in zip(regs, matrix):
        oline = []
        for reg, m in zip(rline, mline):
            v = int(round(m * 2**coeff_frac_width)) & ((1<<coeff_width) - 1)
            dev.set(term, reg, v)
    return ccm_fixed2float(f, coeff_width, coeff_frac_width)

def ccm_float2fixed(matrix, coeff_width=8, coeff_frac_width=5):
    f = (matrix * 2**coeff_frac_width).round().astype(int) & ((1<<coeff_width)-1)
    return f

def ccm_fixed2float(matrix, coeff_width=8, coeff_frac_width=5):
    f = matrix.copy()
    negative = f >> (coeff_width-1)
    f[negative==1] = f[negative==1] - (1 << coeff_width)
    f = f / float(2**coeff_frac_width)
    return f

def quantize_ccm(matrix, coeff_width=8, coeff_frac_width=5):
    return ccm_fixed2float(ccm_float2fixed(matrix, coeff_width, coeff_frac_width), coeff_width, coeff_frac_width)
