#!/usr/bin/env bash
set -euo pipefail

have(){ command -v "$1" &>/dev/null; }

echo "==> Update & Upgrade (with refresh)…"
sudo dnf -y upgrade --refresh

# -------------------------------------------------------
# Enable RPM Fusion (Free + Nonfree)
# -------------------------------------------------------
if ! rpm -qa | grep -q rpmfusion-free-release; then
  ver="$(rpm -E %fedora)"
  echo "==> Enabling RPM Fusion (Free/Nonfree) for Fedora ${ver}…"
  sudo dnf -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"
fi

# -------------------------------------------------------
# Base packages (desktop, tools, audio, mounts, fonts…)
# -------------------------------------------------------
PKGS=(
  # Wayland desktop
  sway swaybg swayidle swaylock waybar wofi wlogout

  # Terminal & CLI utils
  kitty grim slurp wl-clipboard jq ripgrep fd-find fzf ranger stow git tree unzip curl

  # Network tray & autostart helper
  NetworkManager-gnome dex

  # Automount / filesystems / GVFS
  udiskie udisks2 gvfs gvfs-mtp gvfs-smb gvfs-afc exfatprogs ntfs-3g

  # Audio: PipeWire stack (Fedora default, but ensure bits)
  pipewire pipewire-alsa pipewire-pulseaudio wireplumber pipewire-jack pavucontrol
  pipewire-plugin-bluez5

  # Libcanberra events + gsettings/dconf
  libcanberra libcanberra-gtk3 gsettings-desktop-schemas dconf

  # Viewers
  imv mpv zathura zathura-pdf-poppler

  # Fonts
  jetbrains-mono-fonts google-noto-sans-fonts google-noto-emoji-color-fonts

  # Secrets / keyring
  gnome-keyring seahorse libsecret

  # Power & misc
  power-profiles-daemon brightnessctl libayatana-appindicator-gtk3

  # Screenshots annotator (available in recent Fedora)
  swappy
)

echo "==> Installing packages…"
# Try batch install, then retry missing ones individually (so the script continues if a few are unavailable)
if ! sudo dnf -y install "${PKGS[@]}"; then
  echo "==> Some packages failed in bulk. Retrying individually (non-fatal skips)…"
  for p in "${PKGS[@]}"; do
    sudo dnf -y install "$p" || echo "WARN: skipping $p"
  done
fi

# fd on Fedora already installs as 'fd'; nothing to link (Debian needs fdfind→fd, Fedora not).

# -------------------------------------------------------
# Optional: Nerd Font Symbols (for Waybar/Wlogout icons)
# -------------------------------------------------------
read -rp "Install Nerd Font Symbols (user fonts)? [y/N] " nf
if [[ "${nf:-N}" =~ ^[Yy]$ ]]; then
  tmpdir="$(mktemp -d)"
  cd "$tmpdir"
  curl -fL -o SymbolsNerdFont.zip \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
  mkdir -p ~/.local/share/fonts/Nerd
  unzip -o SymbolsNerdFont.zip -d ~/.local/share/fonts/Nerd >/dev/null
  fc-cache -f
  echo "==> Nerd Font Symbols installed."
fi

# -------------------------------------------------------
# User services: udiskie (tray+notify) & cliphist watchers
# -------------------------------------------------------
mkdir -p ~/.config/systemd/user ~/.local/bin

# udiskie user service (only if not provided already)
if ! systemctl --user status udiskie.service &>/dev/null; then
cat > ~/.config/systemd/user/udiskie.service <<'UNIT'
[Unit]
Description=udiskie automounter (tray)
After=graphical-session.target
Wants=graphical-session.target

[Service]
ExecStart=/usr/bin/udiskie --smart-tray --notify
Restart=on-failure

[Install]
WantedBy=default.target
UNIT
  systemctl --user daemon-reload
  systemctl --user enable --now udiskie.service
fi

# cliphist (Fedora repo may have it; if not, offer COPR)
if ! have cliphist; then
  echo "==> 'cliphist' not found. Trying to install…"
  if sudo dnf -y install cliphist; then
    echo "   Installed cliphist from Fedora repos."
  else
    read -rp "Enable COPR 'xfgusta/cliphist' to install cliphist? [y/N] " ch
    if [[ "${ch:-N}" =~ ^[Yy]$ ]]; then
      sudo dnf -y copr enable xfgusta/cliphist
      sudo dnf -y install cliphist || echo "WARN: cliphist still not available."
    fi
  fi
fi

# Create cliphist watcher only if cliphist exists
if have cliphist; then
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

# -------------------------------------------------------
# Libcanberra GTK module via environment.d
# -------------------------------------------------------
mkdir -p ~/.config/environment.d
printf 'GTK_MODULES=canberra-gtk-module\n' > ~/.config/environment.d/50-canberra.conf

# -------------------------------------------------------
# Power Profiles Daemon
# -------------------------------------------------------
sudo systemctl enable --now power-profiles-daemon.service || true

# -------------------------------------------------------
# Optional: Flatpak + Flathub
# -------------------------------------------------------
read -rp "Configure Flatpak + Flathub? [y/N] " fp
if [[ "${fp:-N}" =~ ^[Yy]$ ]]; then
  sudo dnf -y install flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
fi

# -------------------------------------------------------
# Helpful notes
# -------------------------------------------------------
cat <<'NOTE'

Done!

Add these to your Sway config if not present:
  exec --no-startup-id /usr/bin/lxqt-policykit-agent
  exec --no-startup-id nm-applet
  exec --no-startup-id udiskie --smart-tray --notify

Screenshots:
  grim -g "$(slurp)" - | swappy -f -
  (If swappy wasn't available, just use grim+slurp)

Sound events test:
  canberra-gtk-play -i dialog-information

Power profiles:
  powerprofilesctl get
  powerprofilesctl set power-saver|balanced|performance

Log out / reboot once so user services & environment.d are fully active.
NOTE

