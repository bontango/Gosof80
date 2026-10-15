@{
    Name        = 'hw2x_cyclone_10'
    Title       = "GOSOF80 HW 2.x with Cyclone 10 LP (10CL006YE144C8G)"
    BoardId     = 4
    RtlFamily   = 'cyclone_10'
    Options     = @('hw2x')
    BinFolder   = 'Cyclone_10'
    ReleaseArtifact = 'jic'
    Dormant     = $false
    VirtualPins = @()
    Notes       = 'Released up to v4.97 from the old tree. Note: board id 4 collides with the numbering of the HW 4.x board (v4.98, v4.01), which is not part of this tree yet. GOSOF80.cof uses the 10CL006Y flash loader: the .cof of the old folder said EP4CE6 and was NOT what produced the v4.97 release (jic header says 10CL006Y, 2.097.377 B).'
}
