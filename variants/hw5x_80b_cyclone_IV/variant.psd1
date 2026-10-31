@{
    Name        = 'hw5x_80b_cyclone_IV'
    Title       = "GOSOF80B (Gottlieb System 80B sound board MA-766) on HW 5.x with EP4CE6E22C8N core board, ROMs from the EPCS4"
    BoardId     = 8
    TopEntity   = 'gosof80b'
    CommonFiles = 'files_80b_common'
    RtlFamily   = 'hw5x_80b'
    Options     = @()
    BinFolder   = 'HW5x_80B_Cyclone_IV'
    HwName      = 'HW5.x_80B'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 31.10.2026. Own core top\GOSOF80B.vhd (two 6502, 2 x AY-3-8913, AD7528), same board and flash loader as hw5x_cyclone_IV, 24 KB per game in the EPCS4. See docs\GOSOF80B_MA766.md.'
}