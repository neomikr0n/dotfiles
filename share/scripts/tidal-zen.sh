#!/usr/bin/env zsh
export BROWSER=zen
export XDG_CURRENT_DESKTOP=Hyprland
pkill -9 -f tidal-hifi
sleep 1
exec tidal-hifi "$@"
