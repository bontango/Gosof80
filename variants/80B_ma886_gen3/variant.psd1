@{
    Name        = '80B_ma886_gen3'
    Title       = "GOSOF80B (Gottlieb System 80B sound board MA-886 generation 3) on the Gosof80B PCB with the 'dev_open' Cyclone IV board (EP4CE6E22C8), SRAM U1, ROMs from the EPCS16"
    BoardId     = 10
    TopEntity   = 'gosof80b'
    CommonFiles = 'files_886_gen3'
    RtlFamily   = 'hw5x_80b'
    Options     = @()
    BinFolder   = '80B_ma886_gen3'
    HwName      = '80B_ma886_gen3'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 02.11.2026. Core top\GOSOF80B_886.vhd, YM2151 (jt51). Games: Bad Girls, Big House, Hot Shots, Night Moves. ROMs in the external SRAM, 64 KB per game in the EPCS16. See docs\MA-886_Evaluierung.md.'
}
