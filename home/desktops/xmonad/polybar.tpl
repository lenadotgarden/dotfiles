[colors]
bg = @BG@
fg = @FG@
accent = @BLUE@
occ = @OCC@
faint = @EMPTY@
dim = @DIM@
teal = @TEAL@
yellow = @YELLOW@
green = @GREEN@
mauve = @MAUVE@
red = @RED@

[bar/main]
width = 100%
height = 36
bottom = true
background = ${colors.bg}
foreground = ${colors.fg}
font-0 = Iosevka:size=11;3
font-1 = Symbols Nerd Font:size=13;3
modules-left = xworkspaces xwindow
modules-right = wifi bluetooth volume battery clock
module-margin = 2
padding-left = 1
padding-right = 2
tray-position = right
tray-padding = 6
tray-maxsize = 20
tray-background = ${colors.bg}
enable-ipc = true
cursor-click = pointer

[module/xworkspaces]
type = internal/xworkspaces
pin-workspaces = false
enable-click = true
enable-scroll = false
label-active = %name%
label-active-foreground = ${colors.accent}
label-active-padding = 1
label-occupied = %name%
label-occupied-foreground = ${colors.occ}
label-occupied-padding = 1
label-empty = %name%
label-empty-foreground = ${colors.faint}
label-empty-padding = 1
label-urgent = %name%
label-urgent-foreground = ${colors.red}
label-urgent-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:60:...%
label-foreground = ${colors.dim}
format-padding = 2

[module/wifi]
type = custom/script
exec = @XBARMOD@ wifi
interval = 10
format-prefix = " "
format-prefix-foreground = ${colors.teal}
click-left = kitty --class nmtui -e nmtui
click-right = nm-connection-editor

[module/bluetooth]
type = custom/script
exec = @XBARMOD@ bt
interval = 10
format-prefix = " "
format-prefix-foreground = ${colors.accent}
click-left = blueman-manager

[module/volume]
type = custom/script
exec = @XBARMOD@ vol
interval = 2
format-prefix = " "
format-prefix-foreground = ${colors.yellow}
click-left = pavucontrol
click-right = pamixer -t
scroll-up = pamixer -i 5
scroll-down = pamixer -d 5

[module/battery]
type = custom/script
exec = @XBARMOD@ bat
interval = 30
format-prefix = " "
format-prefix-foreground = ${colors.green}


[module/clock]
type = custom/script
exec = @XBARMOD@ clock
interval = 20
format-prefix = " "
format-prefix-foreground = ${colors.mauve}
click-left = xcalendar
click-right = librewolf https://calendar.google.com
