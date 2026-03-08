#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
STOW_PACKAGES=(shell alacritty niri waybar pipewire obs mako fuzzel swaylock xremap fcitx5 wayland-flags git systemd-user scripts wallpaper)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }

confirm() {
    echo ""
    read -rp "$(echo -e "${YELLOW}=> $1 [y/N]${NC} ")" ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# ============================================================
# Phase 1: Package Installation
# ============================================================
phase_packages() {
    info "Phase 1: Package Installation"

    if ! command -v pacman &>/dev/null; then
        error "pacman not found. This script is for Arch Linux."
        return 1
    fi

    # Install official packages
    if [ -f "$DOTFILES_DIR/packages/pacman.txt" ]; then
        info "Installing official packages..."
        sudo pacman -S --needed --noconfirm - < "$DOTFILES_DIR/packages/pacman.txt"
        ok "Official packages installed"
    fi

    # Install paru (AUR helper) if not present
    if ! command -v paru &>/dev/null; then
        info "Installing paru (AUR helper)..."
        local paru_tmp
        paru_tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/paru.git "$paru_tmp/paru"
        (cd "$paru_tmp/paru" && makepkg -si --noconfirm)
        rm -rf "$paru_tmp"
        ok "paru installed"
    fi

    # Import GPG keys required by AUR packages
    local gpg_keys=(
        "3FEF9748469ADBE15DA7CA80AC2D62742012EA22"  # 1Password code signing
    )
    for key in "${gpg_keys[@]}"; do
        if ! gpg --list-keys "$key" &>/dev/null; then
            info "Importing GPG key: $key"
            gpg --recv-keys "$key"
            ok "Imported: $key"
        fi
    done

    # Install AUR packages
    if [ -f "$DOTFILES_DIR/packages/aur.txt" ]; then
        info "Installing AUR packages..."
        paru -S --needed --noconfirm - < "$DOTFILES_DIR/packages/aur.txt"
        ok "AUR packages installed"
    fi
}

# ============================================================
# Phase 2: Dotfiles (Stow)
# ============================================================
phase_dotfiles() {
    info "Phase 2: Dotfiles Deployment (GNU Stow)"

    if ! command -v stow &>/dev/null; then
        error "stow not found. Install with: sudo pacman -S stow"
        return 1
    fi

    cd "$DOTFILES_DIR"

    # Dry run first
    info "Running stow --simulate..."
    local failed=0
    for pkg in "${STOW_PACKAGES[@]}"; do
        if ! stow --simulate --target="$HOME" "$pkg" 2>&1; then
            error "Stow conflict for package: $pkg"
            failed=1
        fi
    done

    if [ "$failed" -eq 1 ]; then
        warn "Conflicts detected. Remove conflicting files and retry."
        warn "You can back up existing files first, then delete them."
        return 1
    fi

    # Deploy
    for pkg in "${STOW_PACKAGES[@]}"; do
        stow --restow --target="$HOME" "$pkg"
        ok "Stowed: $pkg"
    done

}

# ============================================================
# Phase 3: System Configuration (/etc/)
# ============================================================
phase_system() {
    info "Phase 3: System Configuration (/etc/)"

    local etc_dir="$DOTFILES_DIR/etc"

    # Files to copy (relative to etc/)
    local files=(
        "modprobe.d/nvidia.conf"
        "modprobe.d/v4l2loopback.conf"
        "environment"
        "greetd/config.toml"
        "greetd/niri-greeter.kdl"
        "greetd/regreet.css"
        "greetd/regreet.toml"
        "greetd/sway-config"
        "pam.d/swaylock"
        "pam.d/greetd"
        "pam.d/polkit-1"
        "systemd/network/20-wired.network"
        "systemd/system/niri-resume-fix.service"
        "udev/rules.d/99-network-tuning.rules"
        "sysctl.d/99-network-tuning.conf"
        "systemd/system/systemd-networkd-wait-online.service.d/override.conf"
        "pacman.d/hooks/nvidia.hook"
        "modules-load.d/v4l2loopback.conf"
    )

    # System-wide configs - show diff but don't auto-copy (may need manual merge)
    local system_configs=(
        "pacman.conf"
        "locale.gen"
    )

    # Files with hardware-specific UUIDs - show diff but don't auto-copy
    local manual_files=(
        "mkinitcpio.conf"
        "default/grub"
    )

    for f in "${files[@]}" "${system_configs[@]}"; do
        local src="$etc_dir/$f"
        local dst="/etc/$f"
        if [ ! -f "$src" ]; then
            warn "Source not found: $src"
            continue
        fi
        sudo mkdir -p "$(dirname "$dst")"
        if [ -f "$dst" ] && diff -q "$src" "$dst" &>/dev/null; then
            ok "Already matches: $dst"
        else
            info "Diff for $dst:"
            diff --color=auto "$src" "$dst" 2>/dev/null || true
            if confirm "Copy $f to /etc/?"; then
                sudo cp "$src" "$dst"
                ok "Copied: $dst"
            fi
        fi
    done

    # Wallpaper for greetd (greeter user can't access ~/Pictures)
    local lock_bg="$HOME/Pictures/wallpaper/lock_bg.png"
    if [ -f "$lock_bg" ]; then
        sudo mkdir -p /usr/share/backgrounds
        if [ -f /usr/share/backgrounds/lock_bg.png ] && diff -q "$lock_bg" /usr/share/backgrounds/lock_bg.png &>/dev/null; then
            ok "Already matches: /usr/share/backgrounds/lock_bg.png"
        else
            sudo cp "$lock_bg" /usr/share/backgrounds/lock_bg.png
            ok "Copied: /usr/share/backgrounds/lock_bg.png"
        fi
    fi

    echo ""
    warn "=== Manual review required (hardware-specific UUIDs) ==="
    for f in "${manual_files[@]}"; do
        local src="$etc_dir/$f"
        local dst="/etc/$f"
        if [ -f "$src" ] && [ -f "$dst" ]; then
            info "Diff for $dst (review manually, UUIDs are PC-specific):"
            diff --color=auto "$src" "$dst" 2>/dev/null || true
        fi
    done
    warn "Edit /etc/default/grub and /etc/mkinitcpio.conf manually for this hardware."
}

# ============================================================
# Phase 4: Service Enablement
# ============================================================
phase_services() {
    info "Phase 4: Service Enablement"

    local system_services=(
        "bluetooth.service"
        "docker.service"
        "greetd.service"
        "nvidia-suspend.service"
        "nvidia-hibernate.service"
        "nvidia-resume.service"
        "snapper-timeline.timer"
        "snapper-cleanup.timer"
        "systemd-networkd.service"
        "systemd-resolved.service"
        "niri-resume-fix.service"
    )

    local user_services=(
        "obs-meet-bridge.service"
    )

    for svc in "${system_services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            ok "Already enabled: $svc"
        else
            info "Enabling: $svc"
            sudo systemctl enable "$svc"
            ok "Enabled: $svc"
        fi
    done

    for svc in "${user_services[@]}"; do
        if systemctl --user is-enabled "$svc" &>/dev/null; then
            ok "Already enabled (user): $svc"
        else
            info "Enabling (user): $svc"
            systemctl --user enable "$svc"
            ok "Enabled (user): $svc"
        fi
    done
}

# ============================================================
# Phase 5: Post-install
# ============================================================
phase_postinstall() {
    info "Phase 5: Post-install"

    if confirm "Regenerate initramfs (mkinitcpio)?"; then
        sudo mkinitcpio -P
        ok "initramfs regenerated"
    fi

    if confirm "Regenerate GRUB config?"; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        ok "GRUB config regenerated"
    fi

    echo ""
    warn "=== Manual steps remaining ==="
    echo "  1. Register YubiKey for PAM:  pamu2fcfg > ~/.config/Yubico/u2f_keys"
    echo "  2. Configure Snapper:         sudo snapper -c root create-config /"
    echo "  3. Set up fstab:              sudo vi /etc/fstab"
    echo "  4. Update GRUB UUIDs:         sudo vi /etc/default/grub && sudo grub-mkconfig -o /boot/grub/grub.cfg"
    echo "  5. Log in to apps:            Chrome, Slack, 1Password, etc."
    echo ""
}

# ============================================================
# Main
# ============================================================
main() {
    echo ""
    echo "========================================="
    echo "  Arch Linux Environment Setup"
    echo "  dotfiles: $DOTFILES_DIR"
    echo "========================================="
    echo ""

    if confirm "Phase 1: Install packages?"; then
        phase_packages
    fi

    if confirm "Phase 2: Deploy dotfiles (stow)?"; then
        phase_dotfiles
    fi

    if confirm "Phase 3: Copy system configs to /etc/?"; then
        phase_system
    fi

    if confirm "Phase 4: Enable systemd services?"; then
        phase_services
    fi

    if confirm "Phase 5: Post-install tasks?"; then
        phase_postinstall
    fi

    echo ""
    ok "Setup complete!"
}

main "$@"
