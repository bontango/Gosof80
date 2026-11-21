@{
    Name        = '80B_sys3_g1'
    Title       = "GOSOF80B (Gottlieb System 3 sound board MA-886-XXX + MA-1294, group 1 without OKI) on the Gosof80B PCB with the 'dev_open' Cyclone IV board (EP4CE6E22C8), SRAM U1, ROMs from the EPCS16"
    BoardId     = 11
    TopEntity   = 'gosof80b'
    CommonFiles = 'files_886_gen3'
    RtlFamily   = 'hw5x_80b'
    Options     = @()
    BinFolder   = '80B_sys3_g1'
    HwName      = '80B_sys3_g1'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'New 21.11.2026. Core top\GOSOF80B_886.vhd with GEN=3 and SYS3 (8 bit sound command S1..S128), YM2151 (jt51). Games: Lights Camera Action, Bell Ringer, Silver Slugger, Vegas, Deadly Weapon, Title Fight, Car Hop, Hoops. Nudge It (generation 2) is not in here. 64 KB per game in the EPCS16. See docs\System3_Evaluierung.md.'
}
