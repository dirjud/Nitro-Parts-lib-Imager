import numpy

def set_lookup_table(dev, lookup_map, term_name="LookupMap"):
    for idx, value in enumerate(lookup_map):
        dev.set(term_name, idx, value)

def calc_gamma_lookup(gamma, bit_width=8):
    max_pixel = 2**bit_width - 1
    g = 1.0/gamma;
    K = max_pixel / (max_pixel ** g)
    lu = (K * (numpy.arange(max_pixel+1) ** g))

    if bit_width <= 8:
        lu = lu.astype(numpy.uint8)
    elif bit_width <= 16:
        lu = lu.astype(numpy.uint16)
    elif bit_width < 32:
        lu = lu.astype(numpy.uint32)
    return lu


def set_gamma(dev, gamma, bit_width=8, term_name="LookupMap"):
    lu = calc_gamma_lookup(gamma, bit_width)
    set_lookup_table(dev, lu, term_name)
