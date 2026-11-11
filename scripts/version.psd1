# version.psd1 - the software version shared by all GOSOF80 variants.
#
# The design itself carries no version (nothing in the VHDL reads it); the version
# only exists in the release file names: GOSOF80_HW2.x_v<BoardId>.<SwMinor>.<ext>,
# e.g. v4.97 = board id 4 (hw2x_cyclone_10), software .97. A release bumps SwMinor
# here, once, and every board follows. BoardId lives in variants\<name>\variant.psd1.
@{
    SwMinor = '99'
}
