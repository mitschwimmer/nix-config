import Quickshell

Scope {
    Palette { id: palette }
    NiriState { id: niri }

    Sidebar { id: sidebar; palette: palette }
    Launcher { niriState: niri; palette: palette; sidebar: sidebar }
    Wallpaper { niriState: niri; sidebar: sidebar; palette: palette }
    Notifications { niriState: niri; palette: palette }
    Osd { niriState: niri; palette: palette }
    Polkit { palette: palette }
}
