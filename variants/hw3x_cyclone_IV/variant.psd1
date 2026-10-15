@{
    Name        = 'hw3x_cyclone_IV'
    Title       = "GOSOF80 HW 3.x with Cyclone IV E board v6 (EP4CE6F17C8, FBGA256)"
    BoardId     = 6
    RtlFamily   = 'cyclone_IV'
    Options     = @('hw3x')
    BinFolder   = 'HW3x_Cyclone_IV'
    HwName      = 'HW3.x'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Taken over 15.10.2026 from FPGA_source_alt\HW 3.x GOSOF80 - Multi SD - CycloneIV_v6 (released there as GOSOF80_HW3.x_v4.97). Board id 6 from x.98 on - 4 is HW 2.x Cyclone 10. Logic identical to HW 2.x x.97 (diff of the old top levels: only ports - SB_Opt 1 to 8, own SD_Error pin, LED_0 off, DFP_rx input), SD image format of HW 2.x.'
}