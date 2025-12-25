#!/usr/bin/env zsh

# Variables para RX 9070 XT (Navi 48 - RDNA 4)
export RADV_PERFTEST=gpl,nggc,sam,rt
export RADV_DEBUG=novrsflatshading,invariantgeom
export AMD_VULKAN_ICD=RADV
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json

# VKD3D-Proton optimizado
export VKD3D_CONFIG=dxr11,dxr
export VKD3D_FEATURE_LEVEL=12_2
export VKD3D_SHADER_MODEL=6_7

# Proton específico
export PROTON_ENABLE_NVAPI=0
export PROTON_USE_WINED3D=0
export PROTON_LOG=1
export PROTON_LOG_DIR=$HOME/.local/share/Steam/logs/proton

# Mesa optimizations
export MESA_SHADER_CACHE_MAX_SIZE=10G
export mesa_glthread=true

#steam -applaunch 2399830 "$@"
PROTON_LOG=1 steam -applaunch 2399830 && tail -100 /tmp/proton_*.log | grep -i "vulkan\|d3d12\|gpu"
