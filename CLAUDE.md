# Dotfiles - Arch Linux (tromania)

## Overview

GNU Stowによるdotfiles管理リポジトリ。Arch Linux + Niri (Wayland) 環境の設定を別PCに復旧するためのもの。

## Architecture

- **GNU Stow**: ユーザー設定をシンボリックリンクで管理。`~/.dotfiles/` がStowディレクトリ、`$HOME` がターゲット
- **install.sh**: パッケージインストール・システム設定・サービス有効化を5フェーズで自動化
- **etc/**: `/etc/` 以下のシステム設定（Stow対象外、install.shで `sudo cp` 管理）

## Stow Packages

| Package | Target | Contents |
|---------|--------|----------|
| `shell/` | `~/` | `.zshrc`, `.zshenv`, `.gitconfig` |
| `alacritty/` | `~/.config/alacritty/` | `alacritty.toml` |
| `niri/` | `~/.config/niri/` | `config.kdl` (WM設定、3モニター、ワークスペース) |
| `waybar/` | `~/.config/waybar/` | `config.jsonc`, `style.css`, メニューXML |
| `pipewire/` | `~/.config/pipewire/` | ノイズキャンセリング設定 |
| `obs/` | `~/.config/obs-studio/` | virtualcam-toggle.py |
| `mako/` | `~/.config/mako/` | 通知デーモン設定 |
| `fuzzel/` | `~/.config/fuzzel/` | アプリランチャー設定 |
| `swaylock/` | `~/.config/swaylock/` | ロック画面設定 |
| `xremap/` | `~/.config/xremap/` | Emacsキーバインド + CapsLock→Ctrl |
| `fcitx5/` | `~/.config/fcitx5/` | 日本語入力(Mozc)設定 |
| `wayland-flags/` | `~/.config/` | Chrome/Electron/Slack/Notion Waylandフラグ |
| `git/` | `~/.config/git/` | global ignore |
| `systemd-user/` | `~/.config/systemd/user/` | obs-meet-bridge.service |
| `scripts/` | `~/.local/bin/` | カスタムスクリプト群 |

## Key Commands

```bash
# Stow操作（~/.dotfiles/ で実行）
stow --restow --target="$HOME" <package>   # パッケージ展開/再展開
stow --delete --target="$HOME" <package>    # シンボリックリンク削除
stow --simulate --target="$HOME" <package>  # ドライラン

# パッケージリスト更新
pacman -Qen | awk '{print $1}' > packages/pacman.txt
pacman -Qm  | awk '{print $1}' > packages/aur.txt
```

## Conventions

- 新しいアプリの設定を追加するときは、Stowパッケージとしてディレクトリを作る（例: `newapp/.config/newapp/config`）
- `/etc/` 以下のシステム設定は `etc/` ディレクトリに置き、install.shの `phase_system` に追記
- `u2f_keys` やシークレット情報はGitに含めない
- `fstab`, `grub` のUUIDはPC固有なので手動対応

## Environment

- **Host**: tromania
- **OS**: Arch Linux (systemd-boot → GRUB, LUKS + LVM + Btrfs)
- **WM**: Niri (Wayland scrollable tiling)
- **Monitors**: 3x LG 4K (DP-1 center 144Hz, DP-2 right, DP-3 left)
- **GPU**: NVIDIA (nvidia-drm, proprietary driver)
- **Shell**: zsh
- **Terminal**: Alacritty
- **IME**: Fcitx5 + Mozc
- **Audio**: PipeWire + RNNoise
