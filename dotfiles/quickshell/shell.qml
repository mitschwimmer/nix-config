import Quickshell

Scope {
    Palette { id: palette }
    NiriState { id: niri }

    Wallpaper { niriState: niri; palette: palette }
    Notifications { niriState: niri; palette: palette }
    Osd { niriState: niri; palette: palette }
    Polkit { palette: palette }
}
