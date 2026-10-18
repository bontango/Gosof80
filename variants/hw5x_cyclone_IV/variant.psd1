@{
    Name        = 'hw5x_cyclone_IV'
    Title       = "GOSOF80 HW 5.x with EP4CE6E22C8N core board, ROMs from the EPCS4"
    BoardId     = 7
    RtlFamily   = 'cyclone_IV'
    Options     = @('hw5x')
    BinFolder   = 'HW5x_Cyclone_IV'
    HwName      = 'HW5.x'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 18.10.2026 (GOSOF 5.00, Target\GOSOF\v5.x). Same function as HW 4.x (Gottlieb_Test + Gosof_Test, sound test), but a plugged EP4CE6E22C8N core board instead of the integrated Cyclone 10 and NO SD card: the 4 KB per game come from the configuration flash EPCS4 (rtl/hw5x, FLASH_BASE in variant_pkg.vhd). The W25Q64 of the core board sits on user I/O and is not used. Compressed bitstream, otherwise the ROMs do not fit into the 512 KB.'
}