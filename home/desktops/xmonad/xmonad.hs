import System.Exit (ExitCode (ExitSuccess), exitWith)
import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageHelpers (doCenterFloat, isDialog)
import XMonad.Hooks.StatusBar
import XMonad.Hooks.StatusBar.PP
import XMonad.Layout.NoBorders (noBorders, smartBorders)
import XMonad.Layout.Spacing (spacingWithEdge)
import XMonad.Layout.ToggleLayouts (ToggleLayout (..), toggleLayouts)
import XMonad.Util.EZConfig (additionalKeys, additionalKeysP)
import Graphics.X11.ExtraTypes.XF86
import qualified XMonad.StackSet as W

myWorkspaces :: [String]
myWorkspaces = ["1", "2", "3", "4", "5"]

-- AZERTY number row: & é " ' (
wsKeys :: [KeySym]
wsKeys = [xK_ampersand, xK_eacute, xK_quotedbl, xK_apostrophe, xK_parenleft]

myLayout = toggleLayouts (noBorders Full) $
  smartBorders $ spacingWithEdge 10 $ tiled ||| Mirror tiled
  where
    tiled = Tall 1 (3 / 100) (1 / 2)

myManageHook :: ManageHook
myManageHook = composeAll
  [ isDialog --> doCenterFloat
  , className =? "flameshot" --> doFloat
  , className =? "Pavucontrol" --> doCenterFloat
  , className =? "quicklauncher" --> doCenterFloat
  ]

myPP :: PP
myPP = def
  -- three opacity tiers: current = solid pill, occupied = ~70%, empty = ~30%
  { ppCurrent = xmobarColor "#11111b" "#89b4fa" . wrap "  " "  "
  , ppVisible = xmobarColor "#cdd6f4" "" . wrap "  " "  "
  , ppHidden = xmobarColor "#a6adc8" "" . wrap "  " "  "
  , ppHiddenNoWindows = xmobarColor "#45475a" "" . wrap "  " "  "
  , ppTitle = xmobarColor "#6c7086" "" . shorten 50
  , ppSep = "   "
  , ppOrder = \(ws : _ : t : _) -> [ws, t]
  }

myConfig = def
  { modMask = mod4Mask
  , terminal = "kitty"
  , workspaces = myWorkspaces
  , borderWidth = 0
  , normalBorderColor = "#1e1e2e"
  , focusedBorderColor = "#89b4fa"
  , focusFollowsMouse = False
  , layoutHook = myLayout
  , manageHook = myManageHook <+> manageHook def
  }
  `additionalKeysP`
  [ ("M-<Return>", spawn "kitty")
  , ("M-o", spawn "kitty -d ~/Garden -e nvim")
  , ("M-q", kill)
  , ("M-<Space>", spawn "rofi -show drun")
  , ("C-M-<Space>", spawn "rofimoji --action type")
  , ("C-S-s", spawn "flameshot gui")
  , ("M-w", spawn "wallpaper-search")            -- gallery (+ random, + search entry)
  , ("M-S-w", spawn "wallpaper-search --online")  -- search the internet directly
  , ("M-S-l", spawn "loginctl lock-session")
  , ("M-S-e", io (exitWith ExitSuccess))
  , ("M-S-r", spawn "xmonad --recompile && xmonad --restart")
  , ("M1-j", windows W.focusDown)
  , ("M1-k", windows W.focusUp)
  , ("M1-h", sendMessage Shrink)
  , ("M1-l", sendMessage Expand)
  , ("M1-S-j", windows W.swapDown)
  , ("M1-S-k", windows W.swapUp)
  , ("M1-<Return>", windows W.swapMaster)
  , ("M1-f", sendMessage ToggleLayout)
  , ("M1-<Space>", sendMessage NextLayout)
  , ("M1-t", withFocused $ windows . W.sink)
  ]
  `additionalKeys`
  ( [ ((m .|. mod1Mask, k), windows $ f i)
    | (i, k) <- zip myWorkspaces wsKeys
    , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]
    ] ++
    [ ((0, xF86XK_AudioRaiseVolume), spawn "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
    , ((0, xF86XK_AudioLowerVolume), spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    , ((0, xF86XK_AudioMute), spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    , ((0, xF86XK_MonBrightnessUp), spawn "brightnessctl set 5%+")
    , ((0, xF86XK_MonBrightnessDown), spawn "brightnessctl set 5%-")
    ]
  )

main :: IO ()
main = xmonad
  . ewmhFullscreen
  . ewmh
  . withEasySB (statusBarProp "xmobar" (pure myPP)) defToggleStrutsKey
  $ myConfig
