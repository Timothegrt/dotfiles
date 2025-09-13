#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Debian / Ubuntu (APT-based) setup script for sway / Wayland environment.
# Only comments and structural headers have been translated / standardized
# for public release. All executable code, prompts, and German user-facing
# messages are intentionally left unchanged.
# ---------------------------------------------------------------------------

have(){ command -v "$1" &>/dev/null; }

echo "==> Update & upgrade…"
sudo apt update
sudo apt -y full-upgrade

# ---------------------------------------------------------------------------
# Repository packages (apt)
# ---------------------------------------------------------------------------
PKGS=(
  # Wayland desktop components
  sway swaybg swayidle swaylock waybar wofi wlogout

  # Terminal, screenshots & clipboard utilities
  kitty grim slurp wl-clipboard jq ripgrep fd-find fzf ranger stow git tree unzip

  # Network tray & autostart helpers
  network-manager-gnome dex

  # Automount / USB / filesystems
  udiskie udisks2 gvfs gvfs-backends gvfs-fuse exfatprogs ntfs-3g

  # Audio: PipeWire stack (+ Bluetooth / JACK)
  pipewire pipewire-audio pipewire-pulse wireplumber libspa-0.2-bluetooth libspa-0.2-jack pavucontrol

  # Libcanberra (sound events) + GSettings / Dconf tools
  libcanberra0 libcanberra-pulse libcanberra-gtk3-module gsettings-desktop-schemas dconf-cli dconf-gsettings-backend

  # Viewers
  imv mpv zathura zathura-pdf-poppler

  # Fonts (repository)
  fonts-noto-core fonts-noto-color-emoji fonts-jetbrains-mono

  # Secrets / keyring (useful for various apps)
  gnome-keyring seahorse libsecret-1-0

  # Power profiles (battery modes)
  power-profiles-daemon
)

echo "==> Installing packages…"
sudo apt -y install "${PKGS[@]}"

# Debian names fd as fdfind — create a convenience symlink if missing
if ! have fd; then
  sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd || true
fi

# ---------------------------------------------------------------------------
# (Optional) Install Nerd Font Symbols (user font directory)
# ---------------------------------------------------------------------------
read -rp "Install Nerd Font Symbols (symbols only) into user font directory? [y/N] " nf
if [[ "${nf:-N}" =~ ^[Yy]$ ]]; then
  tmpdir="$(mktemp -d)"
  cd "$tmpdir"
  # Small / fast option: only the Symbols Nerd Font (not full families)
  curl -fL -o SymbolsNerdFont.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
  mkdir -p ~/.local/share/fonts/Nerd
  unzip -o SymbolsNerdFont.zip -d ~/.local/share/fonts/Nerd >/dev/null
  fc-cache -f
  echo "==> Nerd Font Symbols installed (user fonts)."
fi

# ---------------------------------------------------------------------------
# Activate user services (PipeWire / udiskie / cliphist)
# ---------------------------------------------------------------------------
echo "==> Enabling user services…"
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service || true
systemctl --user enable --now udiskie.service || true

# Cliphist watcher systemd user unit (create if not yet present)
if ! systemctl --user status cliphist.service &>/dev/null; then
  mkdir -p ~/.local/bin ~/.config/systemd/user
  cat > ~/.local/bin/cliphist-watch.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
wl-paste --type text  --watch cliphist store &
wl-paste --type image --watch cliphist store &
wl-paste --primary --type text  --watch cliphist store &
wl-paste --primary --type image --watch cliphist store &
wait
SH
  chmod +x ~/.local/bin/cliphist-watch.sh

  cat > ~/.config/systemd/user/cliphist.service <<'UNIT'
[Unit]
Description=Cliphist clipboard watchers (Wayland)
After=graphical-session.target
Wants=graphical-session.target

[Service]
ExecStart=%h/.local/bin/cliphist-watch.sh
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable --now cliphist.service
fi

# ---------------------------------------------------------------------------
# Set Libcanberra GTK module (sound events)
# ---------------------------------------------------------------------------
echo "==> Setting GTK_MODULES=canberra-gtk-module via environment.d…"
mkdir -p ~/.config/environment.d
printf 'GTK_MODULES=canberra-gtk-module\n' > ~/.config/environment.d/50-canberra.conf

# ---------------------------------------------------------------------------
# Power Profiles daemon
# ---------------------------------------------------------------------------
echo "==> Enabling power-profiles-daemon…"
sudo systemctl enable --now power-profiles-daemon.service || true

# ---------------------------------------------------------------------------
# (Optional) Flatpak + Flathub
# ---------------------------------------------------------------------------
read -rp "Configure Flatpak + Flathub? [y/N] " fp
if [[ "${fp:-N}" =~ ^[Yy]$ ]]; then
  sudo apt -y install flatpak
  # Add Flathub (idempotent)
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
fi

# ---------------------------------------------------------------------------
# Notes / Hinweise
# ---------------------------------------------------------------------------
cat <<'NOTE'

Done!

Important notes:
- Your sway config should include these autostarts:
  exec --no-startup-id /usr/bin/lxqt-policykit-agent
  exec --no-startup-id nm-applet
- Screenshot workflow:
  grim -g "$(slurp)" - | swappy -f -      # (if 'swappy' missing in repo, fall back to grim+slurp only)
- Test sound events:
  canberra-gtk-play -i dialog-information
- Power profiles:
  powerprofilesctl get
  powerprofilesctl set power-saver|balanced|performance

Restart your graphical session (or the machine) once so user services & env vars apply cleanly.
NOTE

