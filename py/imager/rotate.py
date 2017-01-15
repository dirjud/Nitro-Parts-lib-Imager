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

def plot(bit_depth=8, N=64):
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
