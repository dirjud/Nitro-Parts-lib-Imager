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
                    init=720,
                    mode="write",
                    type="int",
                    comment="""Number of cols output by the imager""",
                ),
                Register(
                    name="num_virtual_cols",
                    width=12,
                    init=10,
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
    ]
)
