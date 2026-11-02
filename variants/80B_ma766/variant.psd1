@{
    Name        = '80B_ma766'
    Title       = "GOSOF80B (Gottlieb System 80B sound board MA-766) on the Gosof80B PCB with the 'dev_open' Cyclone IV board (EP4CE6E22C8), ROMs from the EPCS16"
    BoardId     = 8
    TopEntity   = 'gosof80b'
    CommonFiles = 'files_80b_common'
    RtlFamily   = 'hw5x_80b'
    Options     = @()
    BinFolder   = '80B_ma766'
    HwName      = '80B_ma766'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 31.10.2026 as hw5x_80b_cyclone_IV, moved to the dev_open board 01.11.2026. Own core top\GOSOF80B.vhd (two 6502, 2 x AY-3-8913, AD7528), 24 KB per game in the EPCS16. See docs\GOSOF80B_MA766.md.'
}
