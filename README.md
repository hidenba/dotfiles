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

## YubiKey (FIDO2/U2F) 認証

YubiKeyタッチによるパスワードレス認証を3層で使用している:

### 1. ディスク暗号化解除 (LUKS + FIDO2)

起動時にYubiKeyタッチでLUKSボリュームをアンロックする。

| 項目 | 値 |
|------|-----|
| 方式 | LUKS2 + systemd-fido2 トークン |
| Keyslot 0 | パスワード (フォールバック) |
| Keyslot 1 | FIDO2 (YubiKey) |
| GRUB | `rd.luks.options=<UUID>=fido2-device=auto` |
| initramfs | `sd-encrypt` hook (systemd-based) |

**振る舞い**: 起動時にYubiKeyが接続されていればタッチでアンロック。未接続時はパスワード入力にフォールバック。

**関連ファイル**:
- `etc/default/grub` — `GRUB_CMDLINE_LINUX` に `rd.luks.name=<UUID>=cryptlvm` と `rd.luks.options=<UUID>=fido2-device=auto`
- `etc/mkinitcpio.conf` — HOOKS に `sd-encrypt lvm2`、MODULES に `nvidia nvidia_modeset nvidia_uvm nvidia_drm usbhid xhci_hcd`

### 2. ログイン / 画面ロック / 特権操作 (PAM + U2F)

| 場面 | PAM設定 | 振る舞い |
|------|---------|---------|
| ログイン (greetd) | `etc/pam.d/greetd` | YubiKeyタッチで認証。未接続時はパスワードにフォールバック |
| 画面ロック解除 (swaylock) | `etc/pam.d/swaylock` | 同上 |
| 特権操作 (polkit) | `etc/pam.d/polkit-1` | 同上 |

**PAMルール**:

```
auth [success=done default=ignore] pam_u2f.so cue origin=pam://tromania appid=pam://tromania
auth include system-auth   (or login)
```

- `[success=done default=ignore]` — YubiKeyタッチ成功で即認証完了。キーが未接続 or タッチしなかった場合は無視して次のルール（パスワード認証）へフォールバック
- `cue` — "Please touch the device" プロンプトを表示
- `origin` / `appid` — ホスト名ベース (`pam://tromania`)。新PCではホスト名に合わせて書き換える

### 新規PCでのセットアップ手順

```bash
# --- LUKS FIDO2 登録 ---

# 1. LUKSパーティションにFIDO2トークンを登録
sudo systemd-cryptenroll /dev/<partition> --fido2-device=auto

# 2. /etc/default/grub を編集して新UUIDに書き換え
#    rd.luks.name=<新UUID>=cryptlvm rd.luks.options=<新UUID>=fido2-device=auto

# 3. initramfs と GRUB を再生成
sudo mkinitcpio -P
sudo grub-mkconfig -o /boot/grub/grub.cfg

# --- PAM U2F 登録 ---

# 4. パッケージインストール (install.sh Phase 1 で入る)
sudo pacman -S pam-u2f

# 5. YubiKeyを挿してキーを登録
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys

# 6. バックアップキーを追加登録する場合
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys

# 7. PAM設定のホスト名を書き換え (ホスト名が異なる場合)
# etc/pam.d/ 内の origin=pam://tromania appid=pam://tromania を
# 新ホスト名に置換してから install.sh Phase 3 でコピー
```

### セキュリティ上の注意

- `~/.config/Yubico/u2f_keys` はデバイス固有の公開鍵情報を含むため **Gitに含めない** (`.gitignore`済み)
- LUKS の FIDO2 credential もデバイス固有 — 新PCでは `systemd-cryptenroll` で再登録が必要
- すべての認証ポイントでパスワードフォールバックを維持し、YubiKey紛失時のロックアウトを防止

## その他の注意事項

- `fstab`, `grub` のUUIDはPC固有 → install.shではスキップ、手動設定
- OBSのシーン/プロファイルは追跡しない（ランタイム状態）
