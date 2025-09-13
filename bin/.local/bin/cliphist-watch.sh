#!/usr/bin/env bash
set -euo pipefail
# Default-Clipboard
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
# Primary-Selection (optional, einige Apps nutzen die)
wl-paste --primary --type text  --watch cliphist store &
wl-paste --primary --type image --watch cliphist store &
wait
