import math

def gen_lookup_table(bit_depth=8, N=64):
    """ """
    table = []
    for theta in range(N/4 + 1):
        sin_theta = math.sin(theta * 2 * math.pi / N)
        table.append( int(round(sin_theta * (2**bit_depth))))
    return table
        

def sin_cos_from_table(angle, table):
    N = (len(table)-1)*4
    angle = angle % N
    
    if(angle < N/4):
        sin = table[angle]
        cos = table[N/4 - angle]
    elif(angle < N/2):
        sin = table[N/2 - angle]
        cos = -table[angle - N/4]
    elif(angle < N*3/4):
        sin = -table[angle - N/2]
        cos = -table[N*3/4 -angle]
    else:
        sin = -table[N-angle]
        cos = table[angle-N*3/4]

    return sin, cos


def set_rotation(angle, dev, term, bit_depth=8, sin_reg="sin_theta", cos_reg="cos_theta"):
    """ Provide the angle in degrees"""
    theta = angle/180. * math.pi
    sin_theta = int(round(math.sin(theta) * (2**bit_depth)))
    cos_theta = int(round(math.cos(theta) * (2**bit_depth)))
    dev.set(term, sin_reg, sin_theta)
    dev.set(term, cos_reg, cos_theta)
    return sin_theta/(2.0**bit_depth), cos_theta/(2.0**bit_depth)

def _plot(bit_depth=8, N=64):
    table = gen_lookup_table(bit_depth=bit_depth, N=N)
    sin = []
    cos = []
    for angle in range(N):
        s,c = sin_cos_from_table(angle, table)
        sin.append(s)
        cos.append(c)
    import pylab
    pylab.plot(sin, '.-')
    pylab.plot(cos, '.-')
    pylab.grid(True)
