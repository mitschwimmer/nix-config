import Quickshell

Scope {
    Palette { id: palette }
    NiriState { id: niri }

    Wallpaper { niriState: niri }
    Notifications { niriState: niri; palette: palette }
    Osd { niriState: niri; palette: palette }
}
