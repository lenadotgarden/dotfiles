Config
  { font = "xft:Iosevka,Symbols Nerd Font:size=11:antialias=true"
  , bgColor = "@BG@"
  , fgColor = "@FG@"
  , alpha = 255
  , position = BottomH 36
  , lowerOnStart = True
  , allDesktops = True
  , commands =
      [ Run XMonadLog
      , Run Com "sh" ["-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -c 14"] "wifi" 50
      , Run Com "sh" ["-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"] "bt" 50
      , Run Com "pamixer" ["--get-volume-human"] "vol" 10
      , Run Battery ["-t", "<left>%<acstatus>", "-S", "False", "-L", "20", "-l", "@RED@", "--", "-O", " +", "-o", "", "-i", ""] 50
      , Run Date "%a %d %b  <fc=@BLUE@>%H:%M</fc>" "date" 100
      ]
  , sepChar = "%"
  , alignSep = "}{"
  , template = " %XMonadLog% }{ <action=`kitty --class nmtui -e nmtui`><action=`nm-connection-editor` button=3><fc=@TEAL@></fc> %wifi%</action></action>   <action=`blueman-manager`><fc=@BLUE@></fc> %bt%</action>   <action=`pavucontrol`><action=`pamixer -t` button=3><action=`pamixer -i 5` button=4><action=`pamixer -d 5` button=5><fc=@YELLOW@></fc> %vol%</action></action></action></action>   <fc=@GREEN@></fc> %battery%   <action=`xcalendar`><action=`librewolf https://calendar.google.com` button=3><fc=@MAUVE@></fc> %date%</action></action>                     "
  }}
