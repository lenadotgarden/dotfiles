{ config, lib, pkgs, ... }:

# Light offline French dictation for old CPUs (the 2011 Mac mini cannot build or run
# Handy). whisper.cpp with a small quantised multilingual model (~60 MB, 2 threads):
# press the shortcut once to start recording, press again to stop; the text is typed
# into the focused window. Binary comes from the nixpkgs cache (no compile).
let
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin";
    hash = "sha256-Qi8a5FKt5vMKAE1+XGpDGV5EM7w3C/I/rJzFkfAaiJg=";
  };

  dictate = pkgs.writeShellScriptBin "dictate" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.pipewire pkgs.whisper-cpp pkgs.wtype pkgs.libnotify pkgs.coreutils pkgs.procps ]}:$PATH
    dir="''${XDG_RUNTIME_DIR:-/tmp}/dictate"
    mkdir -p "$dir"
    pidfile="$dir/pid"
    wav="$dir/rec.wav"

    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
      # second press: stop, transcribe, type
      kill -INT "$(cat "$pidfile")"; rm -f "$pidfile"
      sleep 0.3
      notify-send -t 2000 "Dictée" "Transcription..."
      text=$(whisper-cli -m ${model} -l fr -t 2 -nt -np -f "$wav" 2>/dev/null \
        | tr '\n' ' ' | sed 's/^ *//; s/ *$//; s/\[[^]]*\]//g; s/([^)]*)//g')
      rm -f "$wav"
      if [ -n "$text" ]; then
        wtype -- "$text"
      else
        notify-send -t 2000 "Dictée" "Rien compris"
      fi
    else
      # first press: start recording (16 kHz mono, what whisper wants)
      pw-record --rate 16000 --channels 1 "$wav" &
      echo $! > "$pidfile"
      notify-send -t 1500 "Dictée" "Je t'écoute (re-appuie pour finir)"
    fi
  '';
in
{
  home.packages = [ dictate pkgs.libnotify ];
}
