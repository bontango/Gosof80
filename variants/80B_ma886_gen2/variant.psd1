@{
    Name        = '80B_ma886_gen2'
    Title       = "GOSOF80B (Gottlieb System 80B sound board MA-886 generation 2) on the Gosof80B PCB with the 'dev_open' Cyclone IV board (EP4CE6E22C8), SRAM U1, ROMs from the EPCS16"
    BoardId     = 9
    TopEntity   = 'gosof80b'
    CommonFiles = 'files_886_gen2'
    RtlFamily   = 'hw5x_80b'
    Options     = @()
    BinFolder   = '80B_ma886_gen2'
    HwName      = '80B_ma886_gen2'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 02.11.2026. Core top\GOSOF80B_886.vhd, 2 x AY-3-8913, filter MF-4. Games: Victory, Diamond Lady, TX-Sector, Robo-War, Excalibur. ROMs in the external SRAM, 64 KB per game in the EPCS16. See docs\MA-886_Evaluierung.md.'
}
