# dmgbuild settings for the OpenHaze disk image, used by package-dmg.sh.
# Opening the image shows the app on the left and an Applications shortcut on
# the right, over the background Support/makedmgbackground.swift draws.
# Paths are relative to macos/, where package-dmg.sh runs. The window size and
# icon positions match the layout constants in makedmgbackground.swift.

application = "build/OpenHaze.app"

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["OpenHaze.app"]
icon = "Support/AppIcon.icns"

# dmgbuild pairs this with dmg-background@2x.png for Retina displays.
background = "build/dmg-background.png"
window_rect = ((100, 100), (640, 360))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {"OpenHaze.app": (160, 160), "Applications": (480, 160)}
