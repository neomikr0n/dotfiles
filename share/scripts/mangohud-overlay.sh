#!/bin/bash
MANGOHUD=1 MANGOHUD_CONFIG=/home/n30/.config/MangoHud/MangoHud.conf "$@" &
sleep 1
MANGOHUD=1 MANGOHUD_CONFIG=/home/n30/.config/MangoHud/MangoHud.conf MANGOHUD_DLSYM=1 "$@" &
wait