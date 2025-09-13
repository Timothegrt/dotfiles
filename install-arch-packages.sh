#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Arch Linux base setup for a sway / Wayland desktop environment.
# NOTE: Only comments have been translated / aligned for public release.
#       All executable lines, package lists, and user-facing echo messages
#       remain unchanged intentionally.
# ---------------------------------------------------------------------------

have() { command -v "$1" &>/dev/null; }

echo "==> System update…"
sudo pacman -Syu --noconfirm

# ---------------------------------------------------------------------------
# Repository packages (pacman)
# ---------------------------------------------------------------------------
REPO_PKGS=(
  # Window manager / bar / launcher / lock
  sway swaylock swayidle waybar wofi wlogout

  # Terminal & screenshots
  kitty grim slurp swappy wl-clipboard cliphist

  # Network UI & autostart helpers
  network-manager-applet dex

  # Automount / USB / filesystems
  udiskie udisks2 gvfs gvfs-mtp gvfs-gphoto2 ntfs-3g exfatprogs

  # Audio (PipeWire stack) + mixer
  pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol

  # Tools / utilities
  brightnessctl jq unzip ripgrep fd fzf ranger git stow gnupg pass tree

  # Polkit agent & PolicyKit
  polkit lxqt-policykit

  # Libcanberra sound themes + GSettings schemas
  libcanberra libcanberra-pulse gsettings-desktop-schemas dconf

  # Viewers
  imv mpv zathura

  # Fonts (repository variants; it's fine if they exist for you)
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols

  # Power profiles (battery modes)
  power-profiles-daemon
)

echo "==> Installing repository packages…"
sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"

# ---------------------------------------------------------------------------
# AUR packages (optional if available)
# ---------------------------------------------------------------------------
AUR_PKGS=(
  # Wayland wallpaper setter
  waypaper
  # If fonts are only offered via AUR for your mirror, use these names:
  # nerd-fonts-jetbrains-mono nerd-fonts-symbols
)

if have yay; then
  echo "==> Found yay – installing AUR packages…"
  yay -S --needed --noconfirm "${AUR_PKGS[@]}" || true
else
  echo "==> Note: 'yay' not found – skipping AUR packages:"
  printf '   - %s\n' "${AUR_PKGS[@]}"
  echo "   Install yay (or paru) and rerun this script if you want the AUR packages."
fi

# ---------------------------------------------------------------------------
# Enable services (best effort)
# ---------------------------------------------------------------------------
echo "==> Enabling user services (where available)…"
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service || true
systemctl --user enable --now udiskie.service || true
systemctl --user enable --now cliphist.service || true

echo "==> Enabling system service power-profiles-daemon…"
sudo systemctl enable --now power-profiles-daemon.service || true

# ---------------------------------------------------------------------------
# Libcanberra GTK module (sound events)
# ---------------------------------------------------------------------------
echo "==> Setting GTK_MODULES=canberra-gtk-module (via environment.d)…"
mkdir -p ~/.config/environment.d
printf 'GTK_MODULES=canberra-gtk-module\n' > ~/.config/environment.d/50-canberra.conf

# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------
echo
echo "Done! Restart your session once (or run 'systemctl --user daemon-reload')"
echo "so that environment variables & user services load cleanly."
echo
echo "Tips:"
echo "- Sway config should start polkit agent & nm-applet:"
echo "    exec --no-startup-id /usr/bin/lxqt-policykit-agent"
echo "    exec --no-startup-id nm-applet"
echo "- Screenshot region: Print -> grim + slurp + swappy (already installed)."
echo "- Sound events test: canberra-gtk-play -i dialog-information"

