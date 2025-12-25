#!/bin/zsh
echo "=== DIAGNÓSTICO ARK RX 9070 XT ==="
echo "✓ Mesa Git:" $(pacman -Q mesa-git | grep version)
echo "✓ VKD3D Proton:" $(pacman -Q vkd3d-proton 2>/dev/null || echo "No instalado")
echo "✓ Gamemode:" $(which gamemoderun)
echo "✓ RADV Debug:" $RADV_DEBUG
echo "✓ Hyprland fix:" $(grep -c "RADV_DEBUG" $HOME/dotfiles/hyprland.conf)
echo "✓ Mods activos:" $(ls -A "/run/media/n30/nvme_chivos/SteamLibrary/steamapps/common/ARK Survival Ascended/ShooterGame/Content/Mods" 2>/dev/null | wc -l)
