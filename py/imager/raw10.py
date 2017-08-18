import numpy


def packed_cols(cols):
        """
            return the number of columns in 8 bit that the input 10 bit columsn generates
            after being packed.
        """
        bytes_per_row = cols * 5 / 4
        dwords_per_row = bytes_per_row / 4 + (bytes_per_row % 4 > 0 and 1 or 0)
        return dwords_per_row * 4

def unpack(datai):
    """
        datai should be a numpy (8 bit) array of image where
        rows are the number of rows
        and cols are the number of packed columns.
        (see packed_cols)

        returns a numpy array of shape rows,(cols-R) in 16 bit format
        R is the remainder of columns that are not a multiple of 16 bytes
    """

    rows,cols=datai.shape

    dwords_per_row = cols/4
    d=datai[:dwords_per_row*4*rows].view(numpy.uint32)

    valid_per_row = dwords_per_row - (dwords_per_row % 5)

    dv = d.reshape((rows,dwords_per_row))
    dv = dv[:,:valid_per_row]

    dv = dv.reshape((rows * valid_per_row / 5, 5 ))
    # drop lsbs
    data32=dv[:,:4] # drop lsbs
    lsbs32=dv[:,4]

    d8=data32.reshape((len(data32)*4,)).view(numpy.uint8)
    d8=d8.astype(numpy.uint16)

    # add lsbs back in

    for i in range(len(lsbs32)):
        for j in range(16): # 16 lsbs per 32 bit word
            d8[i*16+j] = (d8[i*16+j] << 2) + ((lsbs32[i] >> (j*2)) & 3 )


    d8=d8.reshape((rows,valid_per_row/5*4*4))

    return d8
