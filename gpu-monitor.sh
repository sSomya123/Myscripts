#!/bin/bash

# GPU Usage Fuzzel Menu Script
# Shows GPU utilization and top 3 GPU-using processes

# Check if nvidia-smi is available
if ! command -v nvidia-smi &>/dev/null; then
  echo "Error: nvidia-smi not found" | fuzzel --dmenu
  exit 1
fi

# Get GPU utilization percentage
gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

# Get GPU memory usage
gpu_mem=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | awk -F', ' '{printf "%.1f%%", ($1/$2)*100}')

# Get top 3 processes using GPU
top_procs=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader |
  sort -t',' -k3 -nr |
  head -n 3 |
  awk -F', ' '{printf "  %s (PID: %s) - %s MiB\n", $2, $1, $3}')

# Build the menu content
menu_content="━━━━ GPU USAGE ━━━━
GPU Utilization: ${gpu_util}%
Memory Usage: ${gpu_mem}

━━━━ TOP 3 PROCESSES ━━━━"

if [ -z "$top_procs" ]; then
  menu_content="${menu_content}
  No GPU processes found"
else
  menu_content="${menu_content}
${top_procs}"
fi

menu_content="${menu_content}

━━━━━━━━━━━━━━━━━━━
[R] Refresh
[Q] Quit"

# Show in fuzzel
choice=$(echo "$menu_content" | fuzzel --dmenu --prompt="GPU Monitor: ")

# Handle user choice
case "$choice" in
"[R] Refresh")
  exec "$0" # Re-run the script
  ;;
"[Q] Quit" | "")
  exit 0
  ;;
esac
