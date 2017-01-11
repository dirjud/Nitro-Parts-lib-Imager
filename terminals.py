import nitro, os
from nitro import DeviceInterface, Terminal, Register, SubReg

di = DeviceInterface(
    name="ImageProcessTerminals",
    comment="""Imager Processing Test Terminals""",
    terminal_list = [
        Terminal(
            name="Imager",
            regAddrWidth=16,
            regDataWidth=32,
            register_list=[
                Register(
                    name="enable",
                    width=1,
                    init=0,
                    type="int",
                    mode="write",
                    comment="Start imager",
                    ),
                Register(
                    name="mode",
                    width=4,
                    init=0,
                    mode="write",
                    type="int",
                    comment="""0: pseudo random noise (see noise_seed input)
1: horizontal gradient
2: vertical gradient
3: diagonal gradient
4: constant based on frame number
5: diagonal gradient offset based on frame number.
6: image from memory.    
7: incrementing counter +1 each pixel.
8: bayer
                    """,
                ),
                Register(
                    name="bayer_red",
                    width=10,
                    init=0,
                    mode="write",
                    type="int",
                    comment="""when mode=bayer, this is the value of the red pixel""",
                ),
                Register(
                    name="bayer_gr",
                    width=10,
                    init=0,
                    mode="write",
                    type="int",
                    comment="""when mode=bayer, this is the value of the green pixel on the red row""",
                ),
                Register(
                    name="bayer_gb",
                    width=10,
                    init=0,
                    mode="write",
                    type="int",
                    comment="""when mode=bayer, this is the value of the green pixel on the blue row""",
                ),
                Register(
                    name="bayer_blue",
                    width=10,
                    init=0,
                    mode="write",
                    type="int",
                    comment="""when mode=bayer, this is the value of the blue pixel""",
                ),
                Register(
                    name="num_active_rows",
                    width=12,
                    init=720,
                    mode="write",
                    type="int",
                    comment="""Number of rows output by the imager""",
                ),
                Register(
                    name="num_virtual_rows",
                    width=12,
                    init=10,
                    mode="write",
                    type="int",
                    comment="""Number of rows vblank rows output by the imager""",
                ),
                Register(
                    name="num_active_cols",
                    width=12,
                    init=1280,
                    mode="write",
                    type="int",
                    comment="""Number of cols output by the imager""",
                ),
                Register(
                    name="num_virtual_cols",
                    width=12,
                    init=100,
                    mode="write",
                    type="int",
                    comment="""Number of cols vblank cols output by the imager""",
                ),
                Register(
                    name="sync_row_start",
                    width=13,
                    init=0,
                    mode="write",
                    type="int",
                    comment="THE following two inputs are for simulating varying amounts of exposure for an image sensor that has a sync signal for when the frame is valid. sync is active low and will assert low at strobe_row_start and remain low for sync_rows number of rows.",
                ),
                Register(
                    name="sync_rows",
                    width=12,
                    init=0,
                    mode="write",
                    type="int",
                    comment="The following two inputs are for simulating varying amounts of exposure for an image sensor that has a sync signal for when the frame is valid. sync is active low and will assert low at strobe_row_start and remain low for sync_rows number of rows.",
                ),
                Register(
                    name="noise_seed",
                    width=32,
                    init=0,
                    mode="write",
                    type="int",
                    comment="Noise seed when generating pseudo random noise.",
                ),
            ],
        ),
        Terminal(
            name="RotateTest",
            regAddrWidth=16,
            regDataWidth=32,
            comment="Test Image Process Modules",
            register_list = [
                Register(
                    name="enable",
                    width=1,
                    init=0,
                    type="int",
                    mode="write",
                    comment="Enables testing the rotate.v module",
                ),
            ],
        ),
        Terminal(
            name="CcmTest",
            regAddrWidth=16,
            regDataWidth=32,
            comment="Test Image Process Modules",
            register_list = [
                Register(
                    name="enable",
                    width=1,
                    init=0,
                    type="int",
                    mode="write",
                    comment="Enables CCM module",
                ),
                Register(
                    name="dvi",
                    width=1,
                    init=0,
                    type="trigger",
                    mode="write",
                    comment="Strobes a pixel value into the CCM",
                ),
                Register(
                    name="ri",
                    width=10,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Red Pixel Input Value",
                    ),
                Register(
                    name="gi",
                    width=10,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Green Pixel Input Value",
                    ),
                Register(
                    name="bi",
                    width=10,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Blue Pixel Input Value",
                    ),
                Register(
                    name="ro",
                    width=10,
                    type="int",
                    mode="read",
                    comment="Red Pixel Output Value",
                    ),
                Register(
                    name="go",
                    width=10,
                    type="int",
                    mode="read",
                    comment="Green Pixel Output Value",
                    ),
                Register(
                    name="bo",
                    width=10,
                    type="int",
                    mode="read",
                    comment="Blue Pixel Output Value",
                    ),
                Register(
                    name="RR",
                    width=8,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Red/Red CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="RG",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Red/Green CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="RB",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Red/Blue CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="GR",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Green/Red CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="GG",
                    width=8,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Green/Green CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="GB",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Green/Blue CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="BR",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Blue/Red CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="BG",
                    width=8,
                    init=0x00,
                    type="int",
                    mode="write",
                    comment="Blue/Green CCM Coeff. 5 Fractional bits.",
                    ),
                Register(
                    name="BB",
                    width=8,
                    init=0x20,
                    type="int",
                    mode="write",
                    comment="Blue/Blue CCM Coeff. 5 Fractional bits.",
                    ),
                

            ],
        ),
    ]
)
