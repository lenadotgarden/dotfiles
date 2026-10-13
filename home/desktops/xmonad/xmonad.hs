import Control.Exception (SomeException, evaluate, try)
import System.Environment (getEnv)
import System.Exit (ExitCode (ExitSuccess), exitWith)
import XMonad
import XMonad.Hooks.EwmhDesktops (ewmh, ewmhFullscreen)
import XMonad.Hooks.ManageHelpers (doRectFloat, isDialog)
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

-- plain digit keys too (niri binds both)
wsDigits :: [KeySym]
wsDigits = [xK_1, xK_2, xK_3, xK_4, xK_5]

myLayout = toggleLayouts (noBorders Full) $
  smartBorders $ spacingWithEdge 6 $ tiled ||| Mirror tiled
  where
    tiled = Tall 1 (3 / 100) (3 / 5)

-- floating windows open large (not fullscreen), centered
bigFloat, smallFloat :: ManageHook
bigFloat = doRectFloat (W.RationalRect 0.12 0.1 0.76 0.78)
smallFloat = doRectFloat (W.RationalRect 0.25 0.2 0.5 0.6)

myManageHook :: ManageHook
myManageHook = composeAll
  [ isDialog --> bigFloat
  , className =? "flameshot" --> doFloat
  , className =? "Pavucontrol" --> bigFloat
  , className =? "quicklauncher" --> bigFloat
  , className =? "Blueman-manager" --> smallFloat
  , className =? "Nm-connection-editor" --> smallFloat
  ]

-- "dark" or "light", written by `xtheme`
readMode :: IO String
readMode = do
  r <- try $ do
    home <- getEnv "HOME"
    s <- readFile (home ++ "/.cache/theme/mode")
    _ <- evaluate (length s)
    return s
  return $ case (r :: Either SomeException String) of
    Right s | take 5 s == "light" -> "light"
    _ -> "dark"

-- workspace indicator tiers: current = accent, occupied = ~70%, empty = ~30% (no boxes)
myPP :: X PP
myPP = do
  mode <- io readMode
  let (cur, occ, none, ttl)
        | mode == "light" = ("#1e66f5", "#6c6f85", "#bcc0cc", "#9ca0b0")
        | otherwise = ("#89b4fa", "#a6adc8", "#45475a", "#6c7086")
  return def
    { ppCurrent = xmobarColor cur "" . wrap " " " "
    , ppVisible = xmobarColor occ "" . wrap " " " "
    , ppHidden = xmobarColor occ "" . wrap " " " "
    , ppHiddenNoWindows = xmobarColor none "" . wrap " " " "
    , ppTitle = xmobarColor ttl "" . shorten 50
    , ppWsSep = ""
    , ppSep = "   "
    , ppOrder = \(ws : _ : t : _) -> [ws, t]
    }

myConfig = def
  { modMask = mod1Mask -- Alt = "Mod" (launch/close/exit), Super = navigation (swapped vs niri)
  , terminal = "kitty"
  , workspaces = myWorkspaces
  , borderWidth = 0
  , normalBorderColor = "#1e1e2e"
  , focusedBorderColor = "#89b4fa"
  , focusFollowsMouse = True
  , layoutHook = myLayout
  , manageHook = myManageHook <+> manageHook def
  }
  `additionalKeysP`
  [ -- same actions as niri's "Mod+" bindings, but on Alt
    ("M-<Return>", spawn "kitty")
  , ("M-o", spawn "kitty -d ~/Garden -e nvim")
  , ("M-q", kill)
  , ("M-<Space>", spawn "rofi -show drun -theme ~/.config/rofi/launcher.rasi")
  , ("C-M-<Space>", spawn "rofimoji --action type")
  , ("C-S-s", spawn "flameshot gui")
  , ("M-S-e", io (exitWith ExitSuccess))
  , ("M-S-r", spawn "xmonad --recompile && xmonad --restart")
  , ("M-S-l", spawn "loginctl lock-session")
  , ("M-d", spawn "xtheme toggle")               -- dark / light
  , ("M-w", spawn "wallpaper-search")            -- gallery (+ random, + search entry)
  , ("M-S-w", spawn "wallpaper-search --online")  -- search the internet directly
    -- same actions as niri's "Alt+" bindings, but on Super
  , ("M4-j", windows W.focusDown)
  , ("M4-k", windows W.focusUp)
  , ("M4-h", windows W.focusMaster)
  , ("M4-l", windows W.focusDown)
  , ("M4-S-j", windows W.swapDown)
  , ("M4-S-k", windows W.swapUp)
  , ("M4-S-h", windows W.swapMaster)
  , ("M4-f", sendMessage ToggleLayout)
  , ("M4-m", sendMessage ToggleLayout)
  , ("M4-r", sendMessage NextLayout)
  , ("M4-t", withFocused $ windows . W.sink)
  , ("M4-,", sendMessage (IncMasterN 1))
  , ("M4-.", sendMessage (IncMasterN (-1)))
  ]
  `additionalKeys`
  ( [ ((m .|. mod4Mask, k), windows $ f i)
    | (ks, i) <- zip (zip wsKeys wsDigits) myWorkspaces
    , k <- [fst ks, snd ks]
    , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]
    ] ++
    [ ((mod4Mask, xK_minus), sendMessage Shrink)
    , ((mod4Mask, xK_equal), sendMessage Expand)
    , ((0, xF86XK_AudioRaiseVolume), spawn "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
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
  . withEasySB (statusBarProp "xmobar $HOME/.cache/theme/xmobarrc" myPP) defToggleStrutsKey
  $ myConfig
