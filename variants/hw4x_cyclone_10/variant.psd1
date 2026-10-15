@{
    Name        = 'hw4x_cyclone_10'
    Title       = "GOSOF80 HW 4.x with integrated Cyclone 10 LP (10CL006YE144C8G)"
    BoardId     = 5
    RtlFamily   = 'cyclone_10'
    Options     = @('hw4x')
    BinFolder   = 'HW4x_Cyclone_10'
    HwName      = 'HW4.x'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Taken over 15.10.2026 from FPGA_source_alt\HW 4.x GOSOF80 - Multi SD (released there as v4.01, SD image format v4.x: 64 KB per game with CRC). Board id 5 from x.98 on - 4 is HW 2.x Cyclone 10. Own SD_Card/SPI_Master (rtl/hw4x), soundtest, PLL for the CPU clock.'
}