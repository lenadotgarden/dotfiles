Config
  { font = "xft:Iosevka,Symbols Nerd Font:size=11:antialias=true"
  , bgColor = "@BG@"
  , fgColor = "@FG@"
  , alpha = 215
  , position = BottomH 36
  , lowerOnStart = True
  , allDesktops = True
  , commands =
      [ Run XMonadLog
      , Run Com "sh" ["-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -c 14"] "wifi" 50
      , Run Com "pamixer" ["--get-volume-human"] "vol" 10
      , Run Battery ["-t", "<left>%<acstatus>", "-S", "False", "-L", "20", "-l", "@RED@", "--", "-O", " +", "-o", "", "-i", ""] 50
      , Run Date "%a %d %b  <fc=@BLUE@>%H:%M</fc>" "date" 100
      ]
  , sepChar = "%"
  , alignSep = "}{"
  , template = " %XMonadLog% }{ <fc=@TEAL@></fc> %wifi%   <fc=@YELLOW@></fc> %vol%   <fc=@GREEN@></fc> %battery%   <fc=@MAUVE@></fc> %date%                       "
  }
