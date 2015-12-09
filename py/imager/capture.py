import logging, numpy, nitro, struct, time, types, threading

log = logging.getLogger(__name__)

def verify_checksum(img):
    if(img["header"]["image_type"] & 0x30):
        data = img["data"] >> 4
    else:
        data = img["data"]
    checksum = int(data.sum()) & 0xFFFF
    log.info("Checksum: 0x%04x/0x%04x" % (checksum, img["header"]["checksum"]))
    return  checksum == img["header"]["checksum"]

def decode_header(di, raw_header, extra=None):
    
    # Convert raw header to a dict using info from the di tree.
    header = dict(nitroAPIVersion=nitro.version,
                  )
    if extra:
        header.update(extra)

    if type(raw_header) == numpy.ndarray:
        u16header=raw_header.view(dtype=numpy.uint16)
    elif type(raw_header) == str:
        u16header = numpy.fromstring(raw_header,dtype=numpy.uint16) # in case raw_header isn't a numpy array
    else:
        u8header = numpy.asarray(raw_header,dtype=numpy.uint8)
        u16header = u8header.view(numpy.uint16)

    for reg in di['Image'].values():
        if reg.name=='image_data': continue
        addr = reg.addr
        width = reg.width
        val = 0
        shift=0
        while width>0:
            val = val|(u16header[addr]<<(shift*16))
            addr += 1
            shift += 1
            width -= 16
        header[reg.name]=val
   
    header["timeStamp"] = time.time()
    return header

def verify_header(header):
    if(header["frame_start"] != 0xFFFFFFFE):
        raise Exception("Out of sync: header: start=0x%x len=%d type=0x%x count=%d" % (header["frame_start"], header["frame_length"], header["image_type"], header["frame_count"]))

    if header["frame_length"] > 6e6:
        log.error("Header: %s" % str(header))
        raise Exception("Bad frame length: %d" % header['frame_length'])

def resync(dev, raw_header, di, timeout=None):
    """This will read short frames from the image stream in an attempt
    to find an image header to resync with. Once it finds one, it will
    read the stream until the position of the next start of frame"""

    x = "\x00" * 2**14 #len(self.raw_header)
    frame_start = "\xFE\xFF\xFF\xFF"
    pixel_count = 0

    while pixel_count < (640+100)*(480+100):
        dev.read("Image", 0, x)
        # see if this read has a frame start code in it
        idx = x.rfind(frame_start)
        if idx >= 0:

            # check if we read a complete header
            if(len(x) - idx < len(raw_header)):
                # read the rest of the header
                y = "\xFF" * (len(raw_header) - (len(x) - idx))
                dev.read("Image", 0, y)
                y = x + y
            else:
                y = x

            header = decode_header(di, y[idx:idx+len(raw_header)])
            log.info("Found header="+str(header))
            verify_header(header)
            data_len = header["frame_length"] - (len(y)-idx)
            if(data_len >= 0):
                if(data_len > 0):
                    raw_data = "\x00" * data_len 
                    if timeout is None:
                        dev.read("Image", 0, raw_data)
                    else:
                        dev.read("Image", 0, raw_data, timeout)
                dev.read("Image", 0, raw_header)
                return
            else:
                log.warn("False frame header sync. Continuing to try.")

        pixel_count += len(x)/2
    raise Exception("Failed to resync. Cannot find image header in stream.")

def _capture(dev, img, di, timeout):

    #import pdb
    #pdb.set_trace()

    raw_header = "\x00" * di["Image"]["image_data"].addr*2

    dev.read("Image", 0, raw_header, 1000 if timeout is None else timeout)
    header = decode_header(di, raw_header)
    try:
        verify_header(header)
    except Exception, e:
        log.warn(str(e))
        log.warn("Attempting to resync to stream")
        resync(dev, raw_header, di)
        header = decode_header(di, raw_header)
        verify_header(header)

    img["header"]     = header
    log.debug ( "Header: %s" % str(header) )
    img["raw_header"] = raw_header

    raw_data = img.get("raw_data", None)

    data_len = header["frame_length"] - len(raw_header)

    if(raw_data is None):
        raw_data = numpy.zeros([data_len], dtype=numpy.uint8)
        buf = raw_data.data
    elif(raw_data.__class__.__name__  == "ndarray"):
        if(raw_data.size != data_len):
            raw_data = numpy.zeros([data_len], dtype=numpy.uint8)
        buf = raw_data.data
    elif type(raw_data) in [str, buffer, nitro.Buffer]:
        if(len(raw_data) != data_len):
            raw_data = "\x00" * data_len 
        buf = raw_data
    else:
        raise Exception("Unknown type for img['data']")

    # Now we can read the image data if the buffer is large enough
    if timeout is None:
        dev.read("Image", 0, buf)
    else:
        dev.read("Image", 0, buf, timeout)
    img["raw_data"] = raw_data

def capture(dev, img, timeout=None):
    """Captures an image from 'dev' into dictionary 'img'. If 'img' does
    does have data in it, then it is allocated, otherwise tries to reuse
    data in 'img'"""

    for i in range(10):
        try:
            return _capture(dev, img, dev.get_di(), timeout)
        except Exception, e:
            if(str(e) != "Bad compressed frame"):
                raise
            log.info("Skipping bad compressed frame " + str(i))
    raise Exception("Bad compress frame")



class FileDevice:
    def __init__(self, filename, di):
        self.fd = open(filename,"rb")
        if type(di)==types.StringType:
            di=nitro.load_di(di)
        self.di = di

    def read(self, terminal, address, buf, *args, **kws):
        x = self.fd.read(len(buf))
        if(len(x) != len(buf)):
            raise Exception("EOF")
        buf[:] = x

    def get_di(self):
        return self.di

    def close(self):
        self.fd.close()
