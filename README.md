# dotfiles

Arch Linux (Niri/Wayland) 環境の設定ファイル管理リポジトリ。

[GNU Stow](https://www.gnu.org/software/stow/) によるシンボリックリンク管理 + インストールスクリプトで、別PCへの環境復旧を自動化する。

## 環境

| 項目 | 値 |
|------|-----|
| OS | Arch Linux |
| WM | Niri (Wayland scrollable tiling) |
| モニター | LG 4K x3 (144Hz center + 60Hz left/right) |
| GPU | NVIDIA (proprietary) |
| Shell | zsh |
| Terminal | Alacritty |
| IME | Fcitx5 + Mozc |
| Audio | PipeWire + RNNoise |
| ディスク | LUKS + LVM + Btrfs (Snapper) |

## 構成

```
~/.dotfiles/
├── shell/              # .zshrc, .zshenv, .gitconfig
├── alacritty/          # Alacritty terminal
├── niri/               # Niri WM (3モニター、ワークスペース)
├── waybar/             # ステータスバー
├── pipewire/           # ノイズキャンセリング (RNNoise)
├── obs/                # OBS virtualcam toggle script
├── mako/               # 通知デーモン
├── fuzzel/             # アプリランチャー
├── swaylock/           # ロック画面
├── xremap/             # キーリマップ (CapsLock→Ctrl, Emacs風)
├── fcitx5/             # 日本語入力
├── wayland-flags/      # Chrome/Electron Waylandフラグ
├── git/                # global gitignore
├── systemd-user/       # ユーザーサービス
├── scripts/            # ~/.local/bin/ カスタムスクリプト
├── etc/                # /etc/ システム設定 (Stow対象外)
├── packages/           # pacman/AUR パッケージリスト
└── install.sh          # 環境構築スクリプト
```

## セットアップ

### 新規PCへのインストール

```bash
# 1. リポジトリをクローン
git clone git@github.com:hidenba/dotfiles.git ~/.dotfiles

# 2. インストールスクリプトを実行
cd ~/.dotfiles
./install.sh
```

`install.sh` は5フェーズ構成で、各フェーズ実行前に確認プロンプトが出る:

1. **パッケージ** — pacman + paru(AUR) で一括インストール
2. **Dotfiles** — `stow --restow` で全パッケージ展開
3. **システム設定** — `/etc/` へdiff確認付きコピー
4. **サービス** — systemctl enable (bluetooth, docker, greetd, nvidia 等)
5. **ポストインストール** — mkinitcpio, grub-mkconfig, 手動手順リマインダー

### 既存環境への適用 (初回)

既にファイルが存在する場合は `--adopt` で既存ファイルをStow管理下に取り込む:

```bash
cd ~/.dotfiles
stow --adopt --target="$HOME" shell alacritty niri waybar ...
```

## 日常の操作

```bash
# 設定ファイルの編集 → そのまま反映される (シンボリックリンク)
vim ~/.config/niri/config.kdl   # 実体は ~/.dotfiles/niri/.config/niri/config.kdl

# 変更をコミット
cd ~/.dotfiles
git add -A && git commit -m "update niri config" && git push

# パッケージリスト更新
pacman -Qen | awk '{print $1}' > packages/pacman.txt
pacman -Qm  | awk '{print $1}' > packages/aur.txt

# 新しいアプリの設定を追加
mkdir -p newapp/.config/newapp
mv ~/.config/newapp/config newapp/.config/newapp/
stow --target="$HOME" newapp
```

## 注意事項

- `u2f_keys` はセキュリティ上Gitに含めない（新PCで `pamu2fcfg` で再登録）
- `fstab`, `grub` のUUIDはPC固有 → install.shではスキップ、手動設定
- OBSのシーン/プロファイルは追跡しない（ランタイム状態）
